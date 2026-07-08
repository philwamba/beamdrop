//! Regenerates the cross-platform session-encryption conformance vectors:
//! `cargo run -p beamdrop-crypto --example generate_session_vectors > \
//!   ../../protocol/beamdrop-protocol/test-vectors/session-encryption-v1.json`
//! Platform implementations (Swift/Kotlin/C#) must reproduce these outputs.

use beamdrop_crypto::{EncryptionContext, StaticSecretKey, TransferSession};

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn main() {
    let sender_secret = StaticSecretKey::from_bytes([0x11; 32]);
    let receiver_secret = StaticSecretKey::from_bytes([0x22; 32]);
    let ephemeral_secret = [0x44u8; 32];

    let context = EncryptionContext {
        sender_device_id: "device-sender-01".to_owned(),
        receiver_device_id: "device-receiver-02".to_owned(),
        transfer_id: "tx-0001".to_owned(),
    };

    let sender_public = sender_secret.public_key();
    let receiver_public = receiver_secret.public_key();

    let (handshake, session) = TransferSession::initiate_with_ephemeral(
        &sender_secret,
        &receiver_public,
        &context,
        ephemeral_secret,
    )
    .expect("initiate");

    let chunk0 = session.seal_chunk(0, b"BeamDrop chunk zero").expect("seal");
    let chunk1 = session.seal_chunk(1, b"BeamDrop chunk one").expect("seal");
    let empty = session.seal_chunk(2, b"").expect("seal");

    println!(
        r#"{{
  "description": "BeamDrop session encryption v1 conformance vectors. Derivation: dh1 = X25519(ephemeral_secret, receiver_static_public); dh2 = X25519(sender_static_secret, receiver_static_public); salt = SHA256('BeamDropSession-v1' || transfer_id); info = sender_device_id || 0x00 || receiver_device_id || 0x00 || ephemeral_public || sender_static_public || receiver_static_public; session_key = HKDF-SHA256(salt, dh1 || dh2, info, 32). Chunk sealing: ChaCha20-Poly1305 with nonce = [0x01, 0, 0, 0, BE64(chunk_index)] and AAD = 'beamdrop-chunk-v1' || 0x00 || sender_device_id || 0x00 || receiver_device_id || 0x00 || transfer_id || 0x00 || BE64(chunk_index). Sealed layout: nonce(12) || ciphertext || tag(16).",
  "protocolVersion": 1,
  "context": {{
    "senderDeviceId": "{sender_id}",
    "receiverDeviceId": "{receiver_id}",
    "transferId": "{transfer_id}"
  }},
  "keys": {{
    "senderStaticSecret": "{sender_secret_hex}",
    "senderStaticPublic": "{sender_public_hex}",
    "receiverStaticSecret": "{receiver_secret_hex}",
    "receiverStaticPublic": "{receiver_public_hex}",
    "ephemeralSecret": "{ephemeral_secret_hex}",
    "ephemeralPublic": "{ephemeral_public_hex}"
  }},
  "derived": {{
    "sessionKey": "{session_key_hex}"
  }},
  "chunks": [
    {{ "index": 0, "plaintextUtf8": "BeamDrop chunk zero", "sealed": "{chunk0_hex}" }},
    {{ "index": 1, "plaintextUtf8": "BeamDrop chunk one", "sealed": "{chunk1_hex}" }},
    {{ "index": 2, "plaintextUtf8": "", "sealed": "{empty_hex}" }}
  ]
}}"#,
        sender_id = context.sender_device_id,
        receiver_id = context.receiver_device_id,
        transfer_id = context.transfer_id,
        sender_secret_hex = hex(&[0x11; 32]),
        sender_public_hex = hex(sender_public.as_bytes()),
        receiver_secret_hex = hex(&[0x22; 32]),
        receiver_public_hex = hex(receiver_public.as_bytes()),
        ephemeral_secret_hex = hex(&ephemeral_secret),
        ephemeral_public_hex = hex(&handshake.ephemeral_public_key),
        session_key_hex = hex(session.session_key()),
        chunk0_hex = hex(&chunk0),
        chunk1_hex = hex(&chunk1),
        empty_hex = hex(&empty),
    );
}
