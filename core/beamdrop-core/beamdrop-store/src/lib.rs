use beamdrop_protocol::{Platform, TransferType};
use serde::{Deserialize, Serialize};
use std::error::Error;
use std::fmt;

pub const TRUSTED_PEERS_TABLE: &str = "trusted_peers";
pub const TRANSFER_RECORDS_TABLE: &str = "transfer_records";
pub const AUDIT_EVENTS_TABLE: &str = "audit_events";

pub const CREATE_TRUSTED_PEERS_SQL: &str = "\
CREATE TABLE IF NOT EXISTS trusted_peers (
    device_id TEXT PRIMARY KEY NOT NULL,
    device_name TEXT NOT NULL,
    platform TEXT NOT NULL,
    public_key TEXT NOT NULL,
    fingerprint TEXT NOT NULL,
    trust_status TEXT NOT NULL,
    paired_at TEXT NOT NULL,
    last_seen_at TEXT,
    revoked_at TEXT
);";

pub const CREATE_TRANSFER_RECORDS_SQL: &str = "\
CREATE TABLE IF NOT EXISTS transfer_records (
    transfer_id TEXT PRIMARY KEY NOT NULL,
    sender_device_id TEXT NOT NULL,
    receiver_device_id TEXT NOT NULL,
    transfer_type TEXT NOT NULL,
    file_name TEXT,
    size_bytes INTEGER NOT NULL,
    status TEXT NOT NULL,
    hash_verified INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    completed_at TEXT
);";

pub const CREATE_AUDIT_EVENTS_SQL: &str = "\
CREATE TABLE IF NOT EXISTS audit_events (
    event_id TEXT PRIMARY KEY NOT NULL,
    event_type TEXT NOT NULL,
    device_id TEXT,
    transfer_id TEXT,
    created_at TEXT NOT NULL,
    message TEXT NOT NULL
);";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum PeerTrustStatus {
    Unknown,
    Trusted,
    Revoked,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrustedPeer {
    pub device_id: String,
    pub device_name: String,
    pub platform: Platform,
    pub public_key: String,
    pub fingerprint: String,
    pub trust_status: PeerTrustStatus,
    pub paired_at: String,
    pub last_seen_at: Option<String>,
    pub revoked_at: Option<String>,
}

impl TrustedPeer {
    pub fn can_receive_without_pairing(&self) -> Result<(), StoreError> {
        match self.trust_status {
            PeerTrustStatus::Trusted => Ok(()),
            PeerTrustStatus::Unknown => Err(StoreError::UnknownPeerRejected {
                device_id: self.device_id.clone(),
            }),
            PeerTrustStatus::Revoked => Err(StoreError::RevokedPeerRejected {
                device_id: self.device_id.clone(),
            }),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum StoredTransferStatus {
    Queued,
    WaitingForApproval,
    Transferring,
    Paused,
    Verifying,
    Completed,
    Failed,
    Canceled,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransferRecord {
    pub transfer_id: String,
    pub sender_device_id: String,
    pub receiver_device_id: String,
    pub transfer_type: TransferType,
    pub file_name: Option<String>,
    pub size_bytes: u64,
    pub status: StoredTransferStatus,
    pub hash_verified: bool,
    pub created_at: String,
    pub completed_at: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AuditEventType {
    PeerPaired,
    PeerRevoked,
    UnknownPeerRejected,
    RevokedPeerRejected,
    TransferAccepted,
    TransferRejected,
    TransferCompleted,
    TransferFailed,
    HashVerificationFailed,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AuditEvent {
    pub event_id: String,
    pub event_type: AuditEventType,
    pub device_id: Option<String>,
    pub transfer_id: Option<String>,
    pub created_at: String,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum StoreError {
    UnknownPeerRejected { device_id: String },
    RevokedPeerRejected { device_id: String },
}

impl fmt::Display for StoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UnknownPeerRejected { device_id } => {
                write!(f, "unknown peer rejected: {device_id}")
            }
            Self::RevokedPeerRejected { device_id } => {
                write!(f, "revoked peer rejected: {device_id}")
            }
        }
    }
}

impl Error for StoreError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn peer_with_status(trust_status: PeerTrustStatus) -> TrustedPeer {
        TrustedPeer {
            device_id: "bd-ios-01J2M8R1N6NNYV6S5JX5H3FA0C".to_owned(),
            device_name: "Will's iPhone".to_owned(),
            platform: Platform::Ios,
            public_key: "MCowBQYDK2VuAyEAq37Fsc1O4u93fd1zCIh0zUg6JRZpyc6B2yU0ucqk7E0=".to_owned(),
            fingerprint: "7C9A 2E41 8F03".to_owned(),
            trust_status,
            paired_at: "2026-07-06T14:22:11Z".to_owned(),
            last_seen_at: None,
            revoked_at: None,
        }
    }

    #[test]
    fn rejects_revoked_peer() {
        let peer = peer_with_status(PeerTrustStatus::Revoked);

        assert_eq!(
            peer.can_receive_without_pairing(),
            Err(StoreError::RevokedPeerRejected {
                device_id: "bd-ios-01J2M8R1N6NNYV6S5JX5H3FA0C".to_owned()
            })
        );
    }

    #[test]
    fn allows_trusted_peer() {
        let peer = peer_with_status(PeerTrustStatus::Trusted);

        assert!(peer.can_receive_without_pairing().is_ok());
    }
}
