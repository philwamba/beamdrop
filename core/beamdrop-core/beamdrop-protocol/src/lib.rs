use serde::{Deserialize, Serialize};
use std::error::Error;
use std::fmt;

pub const PROTOCOL_VERSION: &str = "1.0";
pub const DEFAULT_CHUNK_SIZE_BYTES: u64 = 4 * 1024 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Platform {
    Android,
    Ios,
    Macos,
    Windows,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TransferType {
    Text,
    Url,
    File,
    FolderArchive,
    Image,
    Screenshot,
    ClipboardText,
    ClipboardImage,
    PairingRequest,
    PairingAccepted,
    TransferCancel,
    TransferResume,
    DevicePing,
}

impl TransferType {
    pub fn requires_file_metadata(self) -> bool {
        matches!(
            self,
            Self::File | Self::FolderArchive | Self::Image | Self::Screenshot | Self::ClipboardImage
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeviceAdvertisement {
    pub protocol_version: String,
    pub service_name: Option<String>,
    pub device_id: String,
    pub device_name: String,
    pub platform: Platform,
    pub public_key: String,
    pub features: Vec<TransferType>,
    pub port: u16,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PairingRequest {
    pub protocol_version: String,
    pub request_id: String,
    pub pairing_session_id: String,
    pub created_at: String,
    pub expires_at: String,
    pub sender_device_id: String,
    pub sender_device_name: String,
    pub sender_platform: Platform,
    pub sender_public_key: String,
    pub receiver_device_id: String,
    pub qr_nonce: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PairingResponse {
    pub protocol_version: String,
    pub request_id: String,
    pub pairing_session_id: String,
    pub created_at: String,
    pub accepted: bool,
    pub responder_device_id: String,
    pub responder_device_name: String,
    pub responder_platform: Platform,
    pub responder_public_key: String,
    pub trust_fingerprint: Option<String>,
    pub rejection_reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransferEnvelope {
    pub protocol_version: String,
    pub transfer_id: String,
    pub transfer_type: TransferType,
    pub sender_device_id: String,
    pub sender_public_key: String,
    pub receiver_device_id: String,
    pub created_at: String,
    pub requires_approval: bool,
    pub resume_supported: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub encryption: Option<EncryptionParameters>,
    pub payload_metadata: PayloadMetadata,
}

pub const ENCRYPTION_SCHEME_SESSION_V1: &str = "BEAMDROP_SESSION_V1";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EncryptionParameters {
    pub scheme: String,
    pub ephemeral_public_key: String,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PayloadMetadata {
    pub text_preview: Option<String>,
    pub url: Option<String>,
    pub file_name: Option<String>,
    pub mime_type: Option<String>,
    pub size_bytes: Option<u64>,
    pub chunk_size: Option<u64>,
    pub total_chunks: Option<u64>,
    pub sha256: Option<String>,
    pub folder_name: Option<String>,
    pub item_count: Option<u64>,
    pub resume_token: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProtocolError {
    UnsupportedProtocolVersion(String),
    MissingField(&'static str),
    EmptyField(&'static str),
    InvalidPort,
    NoFeatures,
    InvalidChunkSize,
    InvalidSha256,
    InvalidFileName,
    MissingFileMetadata(&'static str),
    MissingIntegrityMetadata(&'static str),
    MissingTextMetadata,
    MissingUrlMetadata,
    UnsupportedEncryptionScheme(String),
    InvalidEphemeralPublicKey,
    Json(String),
}

impl fmt::Display for ProtocolError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UnsupportedProtocolVersion(version) => {
                write!(f, "unsupported protocol version: {version}")
            }
            Self::MissingField(field) => write!(f, "missing required field: {field}"),
            Self::EmptyField(field) => write!(f, "field must not be empty: {field}"),
            Self::InvalidPort => write!(f, "port must be non-zero"),
            Self::NoFeatures => write!(f, "device advertisement must include at least one feature"),
            Self::InvalidChunkSize => write!(f, "chunk size must be greater than zero"),
            Self::InvalidSha256 => write!(f, "sha256 must be a 64-character hex string"),
            Self::InvalidFileName => write!(f, "file name must not contain path separators"),
            Self::MissingFileMetadata(field) => write!(f, "file transfer missing metadata: {field}"),
            Self::MissingIntegrityMetadata(field) => {
                write!(f, "transfer missing integrity metadata: {field}")
            }
            Self::MissingTextMetadata => write!(f, "text transfer missing text metadata"),
            Self::MissingUrlMetadata => write!(f, "URL transfer missing URL metadata"),
            Self::UnsupportedEncryptionScheme(scheme) => {
                write!(f, "unsupported encryption scheme {scheme}")
            }
            Self::InvalidEphemeralPublicKey => {
                write!(f, "ephemeralPublicKey must be 64 hex characters")
            }
            Self::Json(message) => write!(f, "json error: {message}"),
        }
    }
}

impl Error for ProtocolError {}

impl From<serde_json::Error> for ProtocolError {
    fn from(value: serde_json::Error) -> Self {
        Self::Json(value.to_string())
    }
}

pub trait Validate {
    fn validate(&self) -> Result<(), ProtocolError>;
}

impl Validate for DeviceAdvertisement {
    fn validate(&self) -> Result<(), ProtocolError> {
        validate_protocol_version(&self.protocol_version)?;
        validate_non_empty("deviceId", &self.device_id)?;
        validate_non_empty("deviceName", &self.device_name)?;
        validate_non_empty("publicKey", &self.public_key)?;
        if self.features.is_empty() {
            return Err(ProtocolError::NoFeatures);
        }
        if self.port == 0 {
            return Err(ProtocolError::InvalidPort);
        }
        Ok(())
    }
}

impl Validate for PairingRequest {
    fn validate(&self) -> Result<(), ProtocolError> {
        validate_protocol_version(&self.protocol_version)?;
        validate_non_empty("requestId", &self.request_id)?;
        validate_non_empty("pairingSessionId", &self.pairing_session_id)?;
        validate_non_empty("createdAt", &self.created_at)?;
        validate_non_empty("expiresAt", &self.expires_at)?;
        validate_non_empty("senderDeviceId", &self.sender_device_id)?;
        validate_non_empty("senderDeviceName", &self.sender_device_name)?;
        validate_non_empty("senderPublicKey", &self.sender_public_key)?;
        validate_non_empty("receiverDeviceId", &self.receiver_device_id)?;
        validate_non_empty("qrNonce", &self.qr_nonce)?;
        Ok(())
    }
}

impl Validate for PairingResponse {
    fn validate(&self) -> Result<(), ProtocolError> {
        validate_protocol_version(&self.protocol_version)?;
        validate_non_empty("requestId", &self.request_id)?;
        validate_non_empty("pairingSessionId", &self.pairing_session_id)?;
        validate_non_empty("createdAt", &self.created_at)?;
        validate_non_empty("responderDeviceId", &self.responder_device_id)?;
        validate_non_empty("responderDeviceName", &self.responder_device_name)?;
        validate_non_empty("responderPublicKey", &self.responder_public_key)?;
        if self.accepted && self.trust_fingerprint.as_deref().unwrap_or("").trim().is_empty() {
            return Err(ProtocolError::MissingField("trustFingerprint"));
        }
        Ok(())
    }
}

impl Validate for TransferEnvelope {
    fn validate(&self) -> Result<(), ProtocolError> {
        validate_protocol_version(&self.protocol_version)?;
        validate_non_empty("transferId", &self.transfer_id)?;
        validate_non_empty("senderDeviceId", &self.sender_device_id)?;
        validate_non_empty("senderPublicKey", &self.sender_public_key)?;
        validate_non_empty("receiverDeviceId", &self.receiver_device_id)?;
        validate_non_empty("createdAt", &self.created_at)?;
        validate_integrity_metadata(&self.payload_metadata)?;

        if let Some(encryption) = &self.encryption {
            if encryption.scheme != ENCRYPTION_SCHEME_SESSION_V1 {
                return Err(ProtocolError::UnsupportedEncryptionScheme(
                    encryption.scheme.clone(),
                ));
            }
            if encryption.ephemeral_public_key.len() != 64
                || !encryption
                    .ephemeral_public_key
                    .bytes()
                    .all(|b| b.is_ascii_hexdigit())
            {
                return Err(ProtocolError::InvalidEphemeralPublicKey);
            }
        }

        if self.transfer_type.requires_file_metadata() {
            validate_file_metadata(&self.payload_metadata)?;
            if !self.resume_supported
                && self.payload_metadata.size_bytes.unwrap_or(0) > DEFAULT_CHUNK_SIZE_BYTES
            {
                return Err(ProtocolError::MissingField("resumeSupported"));
            }
        }

        match self.transfer_type {
            TransferType::Text | TransferType::ClipboardText => {
                if self.payload_metadata.text_preview.as_deref().unwrap_or("").is_empty()
                    || self.payload_metadata.size_bytes.is_none()
                {
                    return Err(ProtocolError::MissingTextMetadata);
                }
            }
            TransferType::Url => {
                if self.payload_metadata.url.as_deref().unwrap_or("").is_empty()
                    || self.payload_metadata.size_bytes.is_none()
                {
                    return Err(ProtocolError::MissingUrlMetadata);
                }
            }
            _ => {}
        }
        Ok(())
    }
}

pub fn from_json<T>(json: &str) -> Result<T, ProtocolError>
where
    T: for<'de> Deserialize<'de> + Validate,
{
    let value: T = serde_json::from_str(json)?;
    value.validate()?;
    Ok(value)
}

pub fn to_json<T>(value: &T) -> Result<String, ProtocolError>
where
    T: Serialize,
{
    Ok(serde_json::to_string(value)?)
}

fn validate_protocol_version(protocol_version: &str) -> Result<(), ProtocolError> {
    if protocol_version == PROTOCOL_VERSION {
        Ok(())
    } else {
        Err(ProtocolError::UnsupportedProtocolVersion(
            protocol_version.to_owned(),
        ))
    }
}

fn validate_non_empty(field: &'static str, value: &str) -> Result<(), ProtocolError> {
    if value.trim().is_empty() {
        Err(ProtocolError::EmptyField(field))
    } else {
        Ok(())
    }
}

fn validate_file_metadata(metadata: &PayloadMetadata) -> Result<(), ProtocolError> {
    let file_name = require_file_some(metadata.file_name.as_ref(), "fileName")?;
    if !is_safe_file_name(file_name) {
        return Err(ProtocolError::InvalidFileName);
    }
    require_file_some(metadata.mime_type.as_ref(), "mimeType")?;
    Ok(())
}

fn validate_integrity_metadata(metadata: &PayloadMetadata) -> Result<(), ProtocolError> {
    require_some(metadata.mime_type.as_ref(), "mimeType")?;
    require_some(metadata.size_bytes, "sizeBytes")?;
    require_some(metadata.chunk_size, "chunkSize")?;
    require_some(metadata.total_chunks, "totalChunks")?;
    require_some(metadata.sha256.as_ref(), "sha256")?;

    if metadata.chunk_size == Some(0) {
        return Err(ProtocolError::InvalidChunkSize);
    }
    if !is_valid_sha256(metadata.sha256.as_deref().unwrap_or_default()) {
        return Err(ProtocolError::InvalidSha256);
    }
    Ok(())
}

fn require_file_some<T>(value: Option<T>, field: &'static str) -> Result<T, ProtocolError> {
    value.ok_or(ProtocolError::MissingFileMetadata(field))
}

fn require_some<T>(value: Option<T>, field: &'static str) -> Result<T, ProtocolError> {
    value.ok_or(ProtocolError::MissingIntegrityMetadata(field))
}

pub fn is_valid_sha256(value: &str) -> bool {
    value.len() == 64 && value.chars().all(|char| char.is_ascii_hexdigit())
}

pub fn is_safe_file_name(value: &str) -> bool {
    let trimmed = value.trim();
    !trimmed.is_empty()
        && trimmed != "."
        && trimmed != ".."
        && !trimmed.contains('/')
        && !trimmed.contains('\\')
        && !trimmed.contains(':')
        && trimmed.chars().all(|char| !char.is_control())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_advertisement() -> DeviceAdvertisement {
        DeviceAdvertisement {
            protocol_version: PROTOCOL_VERSION.to_owned(),
            service_name: Some("_beamdrop._tcp".to_owned()),
            device_id: "bd-macos-01J2M8Q8RXE4KZ9G7V1N0Q4F2A".to_owned(),
            device_name: "Will's MacBook Pro".to_owned(),
            platform: Platform::Macos,
            public_key: "MCowBQYDK2VuAyEAtqzFJY2dveH2WrN9q9NqbcMTFq0QnV8DScjQ7kSy3xY=".to_owned(),
            features: vec![TransferType::Text, TransferType::File],
            port: 49320,
        }
    }

    #[test]
    fn validates_device_advertisement() {
        assert!(valid_advertisement().validate().is_ok());
    }

    #[test]
    fn rejects_invalid_platform_during_json_deserialization() {
        let json = r#"{
            "protocolVersion":"1.0",
            "deviceId":"bd-linux-01J2M8Q8RXE4KZ9G7V1N0Q4F2A",
            "deviceName":"Linux Box",
            "platform":"linux",
            "publicKey":"MCowBQYDK2VuAyEAtqzFJY2dveH2WrN9q9NqbcMTFq0QnV8DScjQ7kSy3xY=",
            "features":["TEXT"],
            "port":49320
        }"#;

        let result: Result<DeviceAdvertisement, _> = serde_json::from_str(json);
        assert!(result.is_err());
    }

    #[test]
    fn validates_pairing_request() {
        let request = PairingRequest {
            protocol_version: PROTOCOL_VERSION.to_owned(),
            request_id: "pair-req-01J2M8S7Q8A2CPN1P8X5A3K9DK".to_owned(),
            pairing_session_id: "pair-session-01J2M8S2D3N7H6S9ZFV4R7QH2M".to_owned(),
            created_at: "2026-07-06T14:22:00Z".to_owned(),
            expires_at: "2026-07-06T14:24:00Z".to_owned(),
            sender_device_id: "bd-ios-01J2M8R1N6NNYV6S5JX5H3FA0C".to_owned(),
            sender_device_name: "Will's iPhone".to_owned(),
            sender_platform: Platform::Ios,
            sender_public_key: "MCowBQYDK2VuAyEAq37Fsc1O4u93fd1zCIh0zUg6JRZpyc6B2yU0ucqk7E0=".to_owned(),
            receiver_device_id: "bd-macos-01J2M8Q8RXE4KZ9G7V1N0Q4F2A".to_owned(),
            qr_nonce: "qrnonce-01J2M8S55APTE6X2W2PQ3RTBQW".to_owned(),
        };

        assert!(request.validate().is_ok());
    }

    #[test]
    fn validates_file_transfer_envelope() {
        let envelope = TransferEnvelope {
            protocol_version: PROTOCOL_VERSION.to_owned(),
            transfer_id: "tx-file-01J2M8X0E11Y0Y9QVT38A0BHR5".to_owned(),
            transfer_type: TransferType::File,
            sender_device_id: "bd-macos-01J2M8Q8RXE4KZ9G7V1N0Q4F2A".to_owned(),
            sender_public_key: "macos-public-key".to_owned(),
            receiver_device_id: "bd-windows-01J2M8W7Z6HD1DYQKFE1X6V904".to_owned(),
            created_at: "2026-07-06T14:27:18Z".to_owned(),
            requires_approval: true,
            resume_supported: true,
            payload_metadata: PayloadMetadata {
                file_name: Some("BeamDrop-Q3-demo.mov".to_owned()),
                mime_type: Some("video/quicktime".to_owned()),
                size_bytes: Some(187_904_819),
                chunk_size: Some(DEFAULT_CHUNK_SIZE_BYTES),
                total_chunks: Some(45),
                sha256: Some(
                    "6f1d2d9a8b0f73643d20e6f8bdbbcf46c2cf4bfb2f8b2c4ed4db70d49c9b3b2a"
                        .to_owned(),
                ),
                resume_token: Some("resume-01J2M8X3GMC2HEK0MJWQTQ3K3T".to_owned()),
                ..PayloadMetadata::default()
            },
        };

        assert!(envelope.validate().is_ok());
    }

    #[test]
    fn rejects_file_transfer_missing_hash() {
        let envelope = TransferEnvelope {
            protocol_version: PROTOCOL_VERSION.to_owned(),
            transfer_id: "tx-file-01J2M8X0E11Y0Y9QVT38A0BHR5".to_owned(),
            transfer_type: TransferType::File,
            sender_device_id: "bd-macos-01J2M8Q8RXE4KZ9G7V1N0Q4F2A".to_owned(),
            sender_public_key: "macos-public-key".to_owned(),
            receiver_device_id: "bd-windows-01J2M8W7Z6HD1DYQKFE1X6V904".to_owned(),
            created_at: "2026-07-06T14:27:18Z".to_owned(),
            requires_approval: true,
            resume_supported: true,
            payload_metadata: PayloadMetadata {
                file_name: Some("BeamDrop-Q3-demo.mov".to_owned()),
                mime_type: Some("video/quicktime".to_owned()),
                size_bytes: Some(187_904_819),
                chunk_size: Some(DEFAULT_CHUNK_SIZE_BYTES),
                total_chunks: Some(45),
                ..PayloadMetadata::default()
            },
        };

        assert_eq!(
            envelope.validate(),
            Err(ProtocolError::MissingIntegrityMetadata("sha256"))
        );
    }

    #[test]
    fn rejects_path_traversal_file_name() {
        let envelope = TransferEnvelope {
            protocol_version: PROTOCOL_VERSION.to_owned(),
            transfer_id: "tx-file-01J2M8X0E11Y0Y9QVT38A0BHR5".to_owned(),
            transfer_type: TransferType::File,
            sender_device_id: "bd-macos-01J2M8Q8RXE4KZ9G7V1N0Q4F2A".to_owned(),
            sender_public_key: "macos-public-key".to_owned(),
            receiver_device_id: "bd-windows-01J2M8W7Z6HD1DYQKFE1X6V904".to_owned(),
            created_at: "2026-07-06T14:27:18Z".to_owned(),
            requires_approval: true,
            resume_supported: true,
            payload_metadata: PayloadMetadata {
                file_name: Some("../secret.txt".to_owned()),
                mime_type: Some("text/plain".to_owned()),
                size_bytes: Some(1),
                chunk_size: Some(DEFAULT_CHUNK_SIZE_BYTES),
                total_chunks: Some(1),
                sha256: Some("f".repeat(64)),
                ..PayloadMetadata::default()
            },
        };

        assert_eq!(envelope.validate(), Err(ProtocolError::InvalidFileName));
    }
}
