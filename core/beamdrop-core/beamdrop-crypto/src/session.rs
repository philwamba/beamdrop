//! Authenticated transfer session encryption (BeamDrop session protocol v1).
//!
//! Establishes a per-transfer symmetric key between two paired devices using
//! X25519 key agreement, then encrypts each chunk with ChaCha20-Poly1305.
//!
//! Key schedule:
//! - `dh1 = X25519(ephemeral_secret, receiver_static_public)` — receiver confidentiality
//!   and forward secrecy with respect to the sender's static key.
//! - `dh2 = X25519(sender_static_secret, receiver_static_public)` — sender authentication:
//!   only the holder of the paired sender key can derive the session key.
//! - `session_key = HKDF-SHA256(salt = SHA256("BeamDropSession-v1" || transfer_id),
//!    ikm = dh1 || dh2, info = ids || eph_pub || sender_pub || receiver_pub)`.
//!
//! Every chunk nonce is deterministic (direction byte plus big-endian chunk index),
//! which is safe because the session key is unique per transfer, and the AAD binds
//! the sender, receiver, transfer id, and chunk index so ciphertexts cannot be
//! replayed across chunks, transfers, or device pairs.

use crate::{sha256, CryptoError, EncryptionContext, PayloadCipher, PublicKey};
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};
use hkdf::Hkdf;
use sha2::Sha256;
use x25519_dalek::{PublicKey as X25519PublicKey, StaticSecret};

pub const X25519_KEY_LENGTH: usize = 32;
pub const SESSION_KEY_LENGTH: usize = 32;
pub const NONCE_LENGTH: usize = 12;
pub const TAG_LENGTH: usize = 16;
pub const SESSION_PROTOCOL_VERSION: u8 = 1;

const SALT_PREFIX: &[u8] = b"BeamDropSession-v1";
const CHUNK_AAD_PREFIX: &[u8] = b"beamdrop-chunk-v1";
const DIRECTION_SENDER_TO_RECEIVER: u8 = 0x01;

/// A 32-byte X25519 static secret key. Private key material stays in this
/// wrapper; platform layers are expected to load it from their secure store
/// (Keychain, Keystore, DPAPI) rather than persisting it in plaintext.
#[derive(Clone)]
pub struct StaticSecretKey {
    bytes: [u8; X25519_KEY_LENGTH],
}

impl StaticSecretKey {
    pub fn from_bytes(bytes: [u8; X25519_KEY_LENGTH]) -> Self {
        Self { bytes }
    }

    pub fn from_slice(bytes: &[u8]) -> Result<Self, CryptoError> {
        let bytes: [u8; X25519_KEY_LENGTH] = bytes
            .try_into()
            .map_err(|_| CryptoError::InvalidKeyLength)?;
        Ok(Self { bytes })
    }

    /// Generates a fresh static keypair from the operating system RNG.
    pub fn generate() -> Result<(Self, PublicKey), CryptoError> {
        let mut bytes = [0u8; X25519_KEY_LENGTH];
        getrandom::getrandom(&mut bytes).map_err(|_| CryptoError::RandomSourceUnavailable)?;
        let secret = Self::from_bytes(bytes);
        let public = secret.public_key();
        Ok((secret, public))
    }

    pub fn public_key(&self) -> PublicKey {
        let secret = StaticSecret::from(self.bytes);
        let public = X25519PublicKey::from(&secret);
        PublicKey::new(public.as_bytes().to_vec()).expect("32-byte X25519 public key")
    }

    fn as_x25519(&self) -> StaticSecret {
        StaticSecret::from(self.bytes)
    }
}

impl std::fmt::Debug for StaticSecretKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("StaticSecretKey(redacted)")
    }
}

/// The initiator's ephemeral public key, sent alongside the transfer request
/// envelope so the receiver can derive the same session key.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionHandshake {
    pub version: u8,
    pub ephemeral_public_key: [u8; X25519_KEY_LENGTH],
}

/// A per-transfer AEAD session. Data flows sender → receiver; each chunk index
/// must be sealed at most once.
pub struct TransferSession {
    key: [u8; SESSION_KEY_LENGTH],
    context: EncryptionContext,
}

impl std::fmt::Debug for TransferSession {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TransferSession")
            .field("key", &"redacted")
            .field("context", &self.context)
            .finish()
    }
}

impl TransferSession {
    /// Sender side: derive a session key toward `receiver_public` and produce
    /// the handshake the receiver needs to derive the same key.
    pub fn initiate(
        sender_secret: &StaticSecretKey,
        receiver_public: &PublicKey,
        context: &EncryptionContext,
    ) -> Result<(SessionHandshake, Self), CryptoError> {
        let mut ephemeral = [0u8; X25519_KEY_LENGTH];
        getrandom::getrandom(&mut ephemeral).map_err(|_| CryptoError::RandomSourceUnavailable)?;
        Self::initiate_with_ephemeral(sender_secret, receiver_public, context, ephemeral)
    }

    /// Deterministic variant used for cross-platform test vectors. Production
    /// callers must use [`TransferSession::initiate`] so the ephemeral key is
    /// never reused.
    pub fn initiate_with_ephemeral(
        sender_secret: &StaticSecretKey,
        receiver_public: &PublicKey,
        context: &EncryptionContext,
        ephemeral_secret: [u8; X25519_KEY_LENGTH],
    ) -> Result<(SessionHandshake, Self), CryptoError> {
        validate_context(context)?;
        let receiver_public = x25519_public(receiver_public)?;

        let ephemeral = StaticSecret::from(ephemeral_secret);
        let ephemeral_public = X25519PublicKey::from(&ephemeral);

        let dh1 = ephemeral.diffie_hellman(&receiver_public);
        let dh2 = sender_secret.as_x25519().diffie_hellman(&receiver_public);
        reject_low_order(&dh1, &dh2)?;

        let sender_public = sender_secret.public_key();
        let key = derive_session_key(
            context,
            dh1.as_bytes(),
            dh2.as_bytes(),
            ephemeral_public.as_bytes(),
            sender_public.as_bytes(),
            receiver_public.as_bytes(),
        );

        let handshake = SessionHandshake {
            version: SESSION_PROTOCOL_VERSION,
            ephemeral_public_key: *ephemeral_public.as_bytes(),
        };
        Ok((
            handshake,
            Self {
                key,
                context: context.clone(),
            },
        ))
    }

    /// Receiver side: derive the session key from the handshake. `sender_public`
    /// must come from the local trusted-peer store, which is what authenticates
    /// the sender — an attacker without the paired sender secret cannot compute
    /// `dh2` and thus cannot produce ciphertexts that authenticate.
    pub fn accept(
        receiver_secret: &StaticSecretKey,
        sender_public: &PublicKey,
        handshake: &SessionHandshake,
        context: &EncryptionContext,
    ) -> Result<Self, CryptoError> {
        validate_context(context)?;
        if handshake.version != SESSION_PROTOCOL_VERSION {
            return Err(CryptoError::UnsupportedSessionVersion(handshake.version));
        }
        let sender_public_x = x25519_public(sender_public)?;
        let ephemeral_public = X25519PublicKey::from(handshake.ephemeral_public_key);

        let secret = receiver_secret.as_x25519();
        let dh1 = secret.diffie_hellman(&ephemeral_public);
        let dh2 = secret.diffie_hellman(&sender_public_x);
        reject_low_order(&dh1, &dh2)?;

        let receiver_public = receiver_secret.public_key();
        let key = derive_session_key(
            context,
            dh1.as_bytes(),
            dh2.as_bytes(),
            &handshake.ephemeral_public_key,
            sender_public.as_bytes(),
            receiver_public.as_bytes(),
        );

        Ok(Self {
            key,
            context: context.clone(),
        })
    }

    /// Encrypts one chunk. Output layout: `nonce(12) || ciphertext || tag(16)`.
    pub fn seal_chunk(&self, chunk_index: u64, plaintext: &[u8]) -> Result<Vec<u8>, CryptoError> {
        let cipher = ChaCha20Poly1305::new(Key::from_slice(&self.key));
        let nonce_bytes = chunk_nonce(chunk_index);
        let aad = chunk_aad(&self.context, chunk_index);
        let ciphertext = cipher
            .encrypt(
                Nonce::from_slice(&nonce_bytes),
                Payload {
                    msg: plaintext,
                    aad: &aad,
                },
            )
            .map_err(|_| CryptoError::EncryptionFailed)?;

        let mut sealed = Vec::with_capacity(NONCE_LENGTH + ciphertext.len());
        sealed.extend_from_slice(&nonce_bytes);
        sealed.extend_from_slice(&ciphertext);
        Ok(sealed)
    }

    /// Decrypts and authenticates one chunk sealed by [`TransferSession::seal_chunk`].
    pub fn open_chunk(&self, chunk_index: u64, sealed: &[u8]) -> Result<Vec<u8>, CryptoError> {
        if sealed.len() < NONCE_LENGTH + TAG_LENGTH {
            return Err(CryptoError::InvalidCiphertext);
        }
        let (nonce_bytes, ciphertext) = sealed.split_at(NONCE_LENGTH);
        if nonce_bytes != chunk_nonce(chunk_index) {
            return Err(CryptoError::InvalidCiphertext);
        }
        let cipher = ChaCha20Poly1305::new(Key::from_slice(&self.key));
        let aad = chunk_aad(&self.context, chunk_index);
        cipher
            .decrypt(
                Nonce::from_slice(nonce_bytes),
                Payload {
                    msg: ciphertext,
                    aad: &aad,
                },
            )
            .map_err(|_| CryptoError::DecryptionFailed)
    }

    /// Exposes the derived session key for cross-platform conformance tests.
    pub fn session_key(&self) -> &[u8; SESSION_KEY_LENGTH] {
        &self.key
    }
}

impl PayloadCipher for TransferSession {
    fn encrypt(
        &self,
        plaintext: &[u8],
        context: &EncryptionContext,
    ) -> Result<Vec<u8>, CryptoError> {
        if *context != self.context {
            return Err(CryptoError::ContextMismatch);
        }
        self.seal_chunk(0, plaintext)
    }

    fn decrypt(
        &self,
        ciphertext: &[u8],
        context: &EncryptionContext,
    ) -> Result<Vec<u8>, CryptoError> {
        if *context != self.context {
            return Err(CryptoError::ContextMismatch);
        }
        self.open_chunk(0, ciphertext)
    }
}

fn validate_context(context: &EncryptionContext) -> Result<(), CryptoError> {
    if context.sender_device_id.trim().is_empty()
        || context.receiver_device_id.trim().is_empty()
        || context.transfer_id.trim().is_empty()
    {
        return Err(CryptoError::InvalidContext);
    }
    Ok(())
}

fn x25519_public(key: &PublicKey) -> Result<X25519PublicKey, CryptoError> {
    let bytes: [u8; X25519_KEY_LENGTH] = key
        .as_bytes()
        .try_into()
        .map_err(|_| CryptoError::InvalidKeyLength)?;
    Ok(X25519PublicKey::from(bytes))
}

/// X25519 with a low-order peer point yields an all-zero shared secret, which
/// would let an attacker force a predictable key. Reject it outright.
fn reject_low_order(
    dh1: &x25519_dalek::SharedSecret,
    dh2: &x25519_dalek::SharedSecret,
) -> Result<(), CryptoError> {
    if !dh1.was_contributory() || !dh2.was_contributory() {
        return Err(CryptoError::InvalidPeerKey);
    }
    Ok(())
}

fn derive_session_key(
    context: &EncryptionContext,
    dh1: &[u8],
    dh2: &[u8],
    ephemeral_public: &[u8],
    sender_public: &[u8],
    receiver_public: &[u8],
) -> [u8; SESSION_KEY_LENGTH] {
    let mut salt_input = Vec::with_capacity(SALT_PREFIX.len() + context.transfer_id.len());
    salt_input.extend_from_slice(SALT_PREFIX);
    salt_input.extend_from_slice(context.transfer_id.as_bytes());
    let salt = sha256(&salt_input);

    let mut ikm = Vec::with_capacity(dh1.len() + dh2.len());
    ikm.extend_from_slice(dh1);
    ikm.extend_from_slice(dh2);

    let mut info = Vec::new();
    info.extend_from_slice(context.sender_device_id.as_bytes());
    info.push(0);
    info.extend_from_slice(context.receiver_device_id.as_bytes());
    info.push(0);
    info.extend_from_slice(ephemeral_public);
    info.extend_from_slice(sender_public);
    info.extend_from_slice(receiver_public);

    let hkdf = Hkdf::<Sha256>::new(Some(&salt), &ikm);
    let mut key = [0u8; SESSION_KEY_LENGTH];
    hkdf.expand(&info, &mut key)
        .expect("32 bytes is a valid HKDF-SHA256 output length");
    key
}

fn chunk_nonce(chunk_index: u64) -> [u8; NONCE_LENGTH] {
    let mut nonce = [0u8; NONCE_LENGTH];
    nonce[0] = DIRECTION_SENDER_TO_RECEIVER;
    nonce[4..12].copy_from_slice(&chunk_index.to_be_bytes());
    nonce
}

fn chunk_aad(context: &EncryptionContext, chunk_index: u64) -> Vec<u8> {
    let mut aad = Vec::new();
    aad.extend_from_slice(CHUNK_AAD_PREFIX);
    aad.push(0);
    aad.extend_from_slice(context.sender_device_id.as_bytes());
    aad.push(0);
    aad.extend_from_slice(context.receiver_device_id.as_bytes());
    aad.push(0);
    aad.extend_from_slice(context.transfer_id.as_bytes());
    aad.push(0);
    aad.extend_from_slice(&chunk_index.to_be_bytes());
    aad
}

#[cfg(test)]
mod tests {
    use super::*;

    fn context() -> EncryptionContext {
        EncryptionContext {
            sender_device_id: "device-sender-01".to_owned(),
            receiver_device_id: "device-receiver-02".to_owned(),
            transfer_id: "tx-0001".to_owned(),
        }
    }

    fn keypairs() -> (StaticSecretKey, PublicKey, StaticSecretKey, PublicKey) {
        let sender_secret = StaticSecretKey::from_bytes([0x11; 32]);
        let receiver_secret = StaticSecretKey::from_bytes([0x22; 32]);
        let sender_public = sender_secret.public_key();
        let receiver_public = receiver_secret.public_key();
        (sender_secret, sender_public, receiver_secret, receiver_public)
    }

    #[test]
    fn sender_and_receiver_derive_same_session_key() {
        let (sender_secret, sender_public, receiver_secret, receiver_public) = keypairs();
        let context = context();

        let (handshake, sender_session) =
            TransferSession::initiate(&sender_secret, &receiver_public, &context)
                .expect("initiate");
        let receiver_session =
            TransferSession::accept(&receiver_secret, &sender_public, &handshake, &context)
                .expect("accept");

        assert_eq!(sender_session.session_key(), receiver_session.session_key());
    }

    #[test]
    fn round_trips_chunk_encryption() {
        let (sender_secret, sender_public, receiver_secret, receiver_public) = keypairs();
        let context = context();

        let (handshake, sender_session) =
            TransferSession::initiate(&sender_secret, &receiver_public, &context)
                .expect("initiate");
        let receiver_session =
            TransferSession::accept(&receiver_secret, &sender_public, &handshake, &context)
                .expect("accept");

        let plaintext = b"chunk payload bytes";
        let sealed = sender_session.seal_chunk(3, plaintext).expect("seal");
        assert_ne!(&sealed[NONCE_LENGTH..], plaintext.as_slice());

        let opened = receiver_session.open_chunk(3, &sealed).expect("open");
        assert_eq!(opened, plaintext);
    }

    #[test]
    fn rejects_tampered_ciphertext() {
        let (sender_secret, sender_public, receiver_secret, receiver_public) = keypairs();
        let context = context();

        let (handshake, sender_session) =
            TransferSession::initiate(&sender_secret, &receiver_public, &context)
                .expect("initiate");
        let receiver_session =
            TransferSession::accept(&receiver_secret, &sender_public, &handshake, &context)
                .expect("accept");

        let mut sealed = sender_session.seal_chunk(0, b"payload").expect("seal");
        let last = sealed.len() - 1;
        sealed[last] ^= 0xFF;

        assert_eq!(
            receiver_session.open_chunk(0, &sealed),
            Err(CryptoError::DecryptionFailed)
        );
    }

    #[test]
    fn rejects_chunk_replayed_at_different_index() {
        let (sender_secret, sender_public, receiver_secret, receiver_public) = keypairs();
        let context = context();

        let (handshake, sender_session) =
            TransferSession::initiate(&sender_secret, &receiver_public, &context)
                .expect("initiate");
        let receiver_session =
            TransferSession::accept(&receiver_secret, &sender_public, &handshake, &context)
                .expect("accept");

        let sealed = sender_session.seal_chunk(1, b"payload").expect("seal");
        assert!(receiver_session.open_chunk(2, &sealed).is_err());
    }

    #[test]
    fn wrong_sender_key_cannot_authenticate() {
        let (sender_secret, _, receiver_secret, receiver_public) = keypairs();
        let context = context();

        let impostor_secret = StaticSecretKey::from_bytes([0x33; 32]);
        let (handshake, impostor_session) =
            TransferSession::initiate(&impostor_secret, &receiver_public, &context)
                .expect("initiate");

        // Receiver trusts the real sender's public key, not the impostor's.
        let receiver_session = TransferSession::accept(
            &receiver_secret,
            &sender_secret.public_key(),
            &handshake,
            &context,
        )
        .expect("accept");

        let sealed = impostor_session.seal_chunk(0, b"payload").expect("seal");
        assert_eq!(
            receiver_session.open_chunk(0, &sealed),
            Err(CryptoError::DecryptionFailed)
        );
    }

    #[test]
    fn different_transfer_ids_produce_different_keys() {
        let (sender_secret, _, _, receiver_public) = keypairs();
        let mut other_context = context();
        other_context.transfer_id = "tx-0002".to_owned();

        let ephemeral = [0x44; 32];
        let (_, session_a) = TransferSession::initiate_with_ephemeral(
            &sender_secret,
            &receiver_public,
            &context(),
            ephemeral,
        )
        .expect("initiate");
        let (_, session_b) = TransferSession::initiate_with_ephemeral(
            &sender_secret,
            &receiver_public,
            &other_context,
            ephemeral,
        )
        .expect("initiate");

        assert_ne!(session_a.session_key(), session_b.session_key());
    }

    #[test]
    fn rejects_low_order_peer_public_key() {
        let (sender_secret, _, _, _) = keypairs();
        let zero_key = PublicKey::new(vec![0u8; 32]).expect("public key");

        assert_eq!(
            TransferSession::initiate(&sender_secret, &zero_key, &context()).unwrap_err(),
            CryptoError::InvalidPeerKey
        );
    }

    #[test]
    fn rejects_invalid_key_length() {
        let (sender_secret, _, _, _) = keypairs();
        let short_key = PublicKey::new(vec![1, 2, 3]).expect("public key");

        assert_eq!(
            TransferSession::initiate(&sender_secret, &short_key, &context()).unwrap_err(),
            CryptoError::InvalidKeyLength
        );
    }

    #[test]
    fn generated_keypairs_are_unique_and_valid() {
        let (secret_a, public_a) = StaticSecretKey::generate().expect("generate");
        let (_, public_b) = StaticSecretKey::generate().expect("generate");

        assert_eq!(public_a.as_bytes().len(), X25519_KEY_LENGTH);
        assert_ne!(public_a, public_b);
        assert_eq!(secret_a.public_key(), public_a);
    }

    #[test]
    fn payload_cipher_impl_round_trips_and_checks_context() {
        let (sender_secret, sender_public, receiver_secret, receiver_public) = keypairs();
        let context = context();

        let (handshake, sender_session) =
            TransferSession::initiate(&sender_secret, &receiver_public, &context)
                .expect("initiate");
        let receiver_session =
            TransferSession::accept(&receiver_secret, &sender_public, &handshake, &context)
                .expect("accept");

        let sealed = PayloadCipher::encrypt(&sender_session, b"clipboard text", &context)
            .expect("encrypt");
        let opened =
            PayloadCipher::decrypt(&receiver_session, &sealed, &context).expect("decrypt");
        assert_eq!(opened, b"clipboard text");

        let mut wrong_context = context.clone();
        wrong_context.transfer_id = "tx-9999".to_owned();
        assert_eq!(
            PayloadCipher::encrypt(&sender_session, b"x", &wrong_context),
            Err(CryptoError::ContextMismatch)
        );
    }
}
