use sha2::{Digest, Sha256};
use std::error::Error;
use std::fmt;

pub mod session;

pub use session::{
    SessionHandshake, StaticSecretKey, TransferSession, NONCE_LENGTH, SESSION_KEY_LENGTH,
    SESSION_PROTOCOL_VERSION, TAG_LENGTH, X25519_KEY_LENGTH,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublicKey {
    bytes: Vec<u8>,
}

impl PublicKey {
    pub fn new(bytes: Vec<u8>) -> Result<Self, CryptoError> {
        if bytes.is_empty() {
            return Err(CryptoError::EmptyPublicKey);
        }
        Ok(Self { bytes })
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PrivateKeyHandle {
    key_id: String,
}

impl PrivateKeyHandle {
    pub fn new(key_id: impl Into<String>) -> Result<Self, CryptoError> {
        let key_id = key_id.into();
        if key_id.trim().is_empty() {
            return Err(CryptoError::EmptyPrivateKeyHandle);
        }
        Ok(Self { key_id })
    }

    pub fn key_id(&self) -> &str {
        &self.key_id
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeviceKeypair {
    public_key: PublicKey,
    private_key_handle: PrivateKeyHandle,
}

impl DeviceKeypair {
    pub fn from_secure_store(
        public_key: PublicKey,
        private_key_handle: PrivateKeyHandle,
    ) -> Self {
        Self {
            public_key,
            private_key_handle,
        }
    }

    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    pub fn private_key_handle(&self) -> &PrivateKeyHandle {
        &self.private_key_handle
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EncryptionContext {
    pub sender_device_id: String,
    pub receiver_device_id: String,
    pub transfer_id: String,
}

pub trait PayloadCipher {
    fn encrypt(
        &self,
        plaintext: &[u8],
        context: &EncryptionContext,
    ) -> Result<Vec<u8>, CryptoError>;

    fn decrypt(
        &self,
        ciphertext: &[u8],
        context: &EncryptionContext,
    ) -> Result<Vec<u8>, CryptoError>;
}

#[derive(Debug, Default)]
pub struct UnsupportedPayloadCipher;

impl PayloadCipher for UnsupportedPayloadCipher {
    fn encrypt(
        &self,
        _plaintext: &[u8],
        _context: &EncryptionContext,
    ) -> Result<Vec<u8>, CryptoError> {
        Err(CryptoError::EncryptionUnavailable)
    }

    fn decrypt(
        &self,
        _ciphertext: &[u8],
        _context: &EncryptionContext,
    ) -> Result<Vec<u8>, CryptoError> {
        Err(CryptoError::EncryptionUnavailable)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CryptoError {
    EmptyPublicKey,
    EmptyPrivateKeyHandle,
    EncryptionUnavailable,
    EncryptionFailed,
    DecryptionFailed,
    InvalidKeyLength,
    InvalidPeerKey,
    InvalidCiphertext,
    InvalidContext,
    ContextMismatch,
    UnsupportedSessionVersion(u8),
    RandomSourceUnavailable,
}

impl fmt::Display for CryptoError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyPublicKey => write!(f, "public key must not be empty"),
            Self::EmptyPrivateKeyHandle => write!(f, "private key handle must not be empty"),
            Self::EncryptionUnavailable => {
                write!(f, "payload encryption provider has not been configured")
            }
            Self::EncryptionFailed => write!(f, "payload encryption failed"),
            Self::DecryptionFailed => write!(f, "payload decryption failed"),
            Self::InvalidKeyLength => write!(f, "key must be exactly 32 bytes"),
            Self::InvalidPeerKey => write!(f, "peer public key is invalid or low-order"),
            Self::InvalidCiphertext => write!(f, "sealed payload is malformed"),
            Self::InvalidContext => write!(f, "encryption context fields must not be empty"),
            Self::ContextMismatch => write!(f, "payload context does not match session context"),
            Self::UnsupportedSessionVersion(version) => {
                write!(f, "unsupported session protocol version {version}")
            }
            Self::RandomSourceUnavailable => write!(f, "operating system RNG unavailable"),
        }
    }
}

impl Error for CryptoError {}

pub fn sha256(bytes: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    hasher.finalize().into()
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    to_hex(&sha256(bytes))
}

pub fn verify_sha256(bytes: &[u8], expected_hex: &str) -> bool {
    sha256_hex(bytes).eq_ignore_ascii_case(expected_hex)
}

pub fn peer_fingerprint(public_key: &PublicKey) -> String {
    let digest = sha256(public_key.as_bytes());
    digest
        .iter()
        .take(6)
        .map(|byte| format!("{byte:02X}"))
        .collect::<Vec<_>>()
        .join(" ")
}

fn to_hex(bytes: &[u8]) -> String {
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        output.push_str(&format!("{byte:02x}"));
    }
    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verifies_sha256_hash() {
        let payload = b"BeamDrop";
        let expected = "f7ca7c61125005f4ec9b024022a08bc887908206357c8ebf29595d738f6b14a4";

        assert!(verify_sha256(payload, expected));
        assert!(!verify_sha256(payload, "0000000000000000000000000000000000000000000000000000000000000000"));
    }

    #[test]
    fn creates_peer_fingerprint_from_public_key() {
        let key = PublicKey::new(b"test-public-key".to_vec()).expect("public key");
        let fingerprint = peer_fingerprint(&key);

        assert_eq!(fingerprint.split(' ').count(), 6);
    }

    #[test]
    fn rejects_empty_public_key() {
        assert_eq!(PublicKey::new(Vec::new()), Err(CryptoError::EmptyPublicKey));
    }

    #[test]
    fn unsupported_cipher_fails_safely() {
        let cipher = UnsupportedPayloadCipher;
        let context = EncryptionContext {
            sender_device_id: "sender".to_owned(),
            receiver_device_id: "receiver".to_owned(),
            transfer_id: "transfer".to_owned(),
        };

        assert_eq!(
            cipher.encrypt(b"payload", &context),
            Err(CryptoError::EncryptionUnavailable)
        );
    }
}
