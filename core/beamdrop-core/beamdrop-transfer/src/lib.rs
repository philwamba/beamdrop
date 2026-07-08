use beamdrop_crypto::{verify_sha256, CryptoError, TransferSession};
use std::collections::BTreeSet;
use std::error::Error;
use std::fmt;

pub mod checkpoint;

pub use checkpoint::{TransferCheckpoint, CHECKPOINT_FORMAT_VERSION};

pub const DEFAULT_CHUNK_SIZE_BYTES: u64 = 4 * 1024 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransferStatus {
    Queued,
    WaitingForApproval,
    Transferring,
    Paused,
    Resuming,
    Verifying,
    Completed,
    Failed,
    Canceled,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChunkMetadata {
    pub index: u64,
    pub offset: u64,
    pub size: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChunkPlan {
    pub file_size: u64,
    pub chunk_size: u64,
    pub total_chunks: u64,
    pub chunks: Vec<ChunkMetadata>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResumePlan {
    pub transfer_id: String,
    pub total_chunks: u64,
    pub completed_chunks: BTreeSet<u64>,
    pub missing_chunks: Vec<u64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TransferProgress {
    pub bytes_transferred: u64,
    pub total_bytes: u64,
}

impl TransferProgress {
    pub fn fraction(self) -> f64 {
        if self.total_bytes == 0 {
            return 1.0;
        }
        (self.bytes_transferred.min(self.total_bytes) as f64) / (self.total_bytes as f64)
    }

    pub fn percent(self) -> u8 {
        (self.fraction() * 100.0).round() as u8
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransferError {
    InvalidChunkSize,
    MissingTransferId,
    CompletedChunkOutOfRange { chunk_index: u64, total_chunks: u64 },
    ChunkSizeMismatch { chunk_index: u64, expected: u64, actual: u64 },
    InvalidExpectedHash,
    CheckpointSerializationFailed,
    CheckpointParseFailed,
    UnsupportedCheckpointVersion(u32),
    Encryption(CryptoError),
}

impl From<CryptoError> for TransferError {
    fn from(error: CryptoError) -> Self {
        Self::Encryption(error)
    }
}

impl fmt::Display for TransferError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidChunkSize => write!(f, "chunk size must be greater than zero"),
            Self::MissingTransferId => write!(f, "transfer id must not be empty"),
            Self::CompletedChunkOutOfRange {
                chunk_index,
                total_chunks,
            } => write!(
                f,
                "completed chunk {chunk_index} is outside total chunk count {total_chunks}"
            ),
            Self::ChunkSizeMismatch {
                chunk_index,
                expected,
                actual,
            } => write!(
                f,
                "chunk {chunk_index} payload is {actual} bytes but the plan expects {expected}"
            ),
            Self::InvalidExpectedHash => {
                write!(f, "expected hash must be a 64-character SHA-256 hex digest")
            }
            Self::CheckpointSerializationFailed => write!(f, "checkpoint serialization failed"),
            Self::CheckpointParseFailed => write!(f, "checkpoint is not valid JSON"),
            Self::UnsupportedCheckpointVersion(version) => {
                write!(f, "unsupported checkpoint format version {version}")
            }
            Self::Encryption(error) => write!(f, "chunk encryption failed: {error}"),
        }
    }
}

impl Error for TransferError {}

pub fn calculate_chunks(file_size: u64, chunk_size: u64) -> Result<ChunkPlan, TransferError> {
    if chunk_size == 0 {
        return Err(TransferError::InvalidChunkSize);
    }

    let total_chunks = if file_size == 0 {
        1
    } else {
        ((file_size - 1) / chunk_size) + 1
    };

    let mut chunks = Vec::with_capacity(total_chunks as usize);
    for index in 0..total_chunks {
        let offset = index * chunk_size;
        let remaining = file_size.saturating_sub(offset);
        let size = if file_size == 0 {
            0
        } else {
            remaining.min(chunk_size)
        };
        chunks.push(ChunkMetadata {
            index,
            offset,
            size,
        });
    }

    Ok(ChunkPlan {
        file_size,
        chunk_size,
        total_chunks,
        chunks,
    })
}

pub fn plan_resume(
    transfer_id: impl Into<String>,
    total_chunks: u64,
    completed_chunks: impl IntoIterator<Item = u64>,
) -> Result<ResumePlan, TransferError> {
    let transfer_id = transfer_id.into();
    if transfer_id.trim().is_empty() {
        return Err(TransferError::MissingTransferId);
    }

    let completed_chunks: BTreeSet<u64> = completed_chunks.into_iter().collect();
    for chunk_index in &completed_chunks {
        if *chunk_index >= total_chunks {
            return Err(TransferError::CompletedChunkOutOfRange {
                chunk_index: *chunk_index,
                total_chunks,
            });
        }
    }

    let missing_chunks = (0..total_chunks)
        .filter(|index| !completed_chunks.contains(index))
        .collect();

    Ok(ResumePlan {
        transfer_id,
        total_chunks,
        completed_chunks,
        missing_chunks,
    })
}

pub fn verify_final_hash(payload: &[u8], expected_sha256_hex: &str) -> bool {
    verify_sha256(payload, expected_sha256_hex)
}

/// Seals one planned chunk for the wire. The payload length must match the
/// chunk plan so a desynced sender fails loudly instead of producing a file
/// that only fails at final-hash time.
pub fn seal_planned_chunk(
    session: &TransferSession,
    chunk: &ChunkMetadata,
    payload: &[u8],
) -> Result<Vec<u8>, TransferError> {
    if payload.len() as u64 != chunk.size {
        return Err(TransferError::ChunkSizeMismatch {
            chunk_index: chunk.index,
            expected: chunk.size,
            actual: payload.len() as u64,
        });
    }
    Ok(session.seal_chunk(chunk.index, payload)?)
}

/// Opens one received chunk, authenticates it, checks it against the plan,
/// and records it in the checkpoint so the transfer can resume after a crash.
pub fn open_planned_chunk(
    session: &TransferSession,
    chunk: &ChunkMetadata,
    sealed: &[u8],
    checkpoint: &mut TransferCheckpoint,
) -> Result<Vec<u8>, TransferError> {
    let payload = session.open_chunk(chunk.index, sealed)?;
    if payload.len() as u64 != chunk.size {
        return Err(TransferError::ChunkSizeMismatch {
            chunk_index: chunk.index,
            expected: chunk.size,
            actual: payload.len() as u64,
        });
    }
    checkpoint.record_chunk(chunk.index)?;
    Ok(payload)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn calculates_single_chunk_for_small_file() {
        let plan = calculate_chunks(1024, DEFAULT_CHUNK_SIZE_BYTES).expect("chunk plan");

        assert_eq!(plan.total_chunks, 1);
        assert_eq!(plan.chunks[0].offset, 0);
        assert_eq!(plan.chunks[0].size, 1024);
    }

    #[test]
    fn calculates_multiple_chunks_for_large_file() {
        let file_size = (DEFAULT_CHUNK_SIZE_BYTES * 2) + 7;
        let plan = calculate_chunks(file_size, DEFAULT_CHUNK_SIZE_BYTES).expect("chunk plan");

        assert_eq!(plan.total_chunks, 3);
        assert_eq!(plan.chunks[0].size, DEFAULT_CHUNK_SIZE_BYTES);
        assert_eq!(plan.chunks[1].size, DEFAULT_CHUNK_SIZE_BYTES);
        assert_eq!(plan.chunks[2].offset, DEFAULT_CHUNK_SIZE_BYTES * 2);
        assert_eq!(plan.chunks[2].size, 7);
    }

    #[test]
    fn calculates_transfer_progress() {
        let progress = TransferProgress {
            bytes_transferred: 25,
            total_bytes: 100,
        };

        assert_eq!(progress.fraction(), 0.25);
        assert_eq!(progress.percent(), 25);
    }

    #[test]
    fn plans_missing_chunks_for_resume() {
        let plan = plan_resume("tx-file-01", 5, [0, 2, 4]).expect("resume plan");

        assert_eq!(plan.missing_chunks, vec![1, 3]);
    }

    #[test]
    fn verifies_final_hash() {
        let payload = b"BeamDrop";
        let expected = "f7ca7c61125005f4ec9b024022a08bc887908206357c8ebf29595d738f6b14a4";

        assert!(verify_final_hash(payload, expected));
    }

    mod encrypted_pipeline {
        use super::super::*;
        use beamdrop_crypto::{sha256_hex, EncryptionContext, StaticSecretKey};

        fn sessions() -> (TransferSession, TransferSession) {
            let sender_secret = StaticSecretKey::from_bytes([0x11; 32]);
            let receiver_secret = StaticSecretKey::from_bytes([0x22; 32]);
            let context = EncryptionContext {
                sender_device_id: "sender".to_owned(),
                receiver_device_id: "receiver".to_owned(),
                transfer_id: "tx-pipeline-01".to_owned(),
            };
            let (handshake, sender_session) = TransferSession::initiate(
                &sender_secret,
                &receiver_secret.public_key(),
                &context,
            )
            .expect("initiate");
            let receiver_session = TransferSession::accept(
                &receiver_secret,
                &sender_secret.public_key(),
                &handshake,
                &context,
            )
            .expect("accept");
            (sender_session, receiver_session)
        }

        #[test]
        fn transfers_file_encrypted_with_resume_after_interruption() {
            let (sender_session, receiver_session) = sessions();

            let file: Vec<u8> = (0..10_000u32).flat_map(|i| i.to_le_bytes()).collect();
            let chunk_size = 16 * 1024;
            let plan = calculate_chunks(file.len() as u64, chunk_size).expect("plan");
            let expected_hash = sha256_hex(&file);

            let mut checkpoint = TransferCheckpoint::new(
                "tx-pipeline-01",
                file.len() as u64,
                chunk_size,
                plan.total_chunks,
                expected_hash.clone(),
            )
            .expect("checkpoint");

            let mut received = vec![0u8; file.len()];
            // First attempt: connection drops after the first chunk.
            for chunk in plan.chunks.iter().take(1) {
                let payload =
                    &file[chunk.offset as usize..(chunk.offset + chunk.size) as usize];
                let sealed =
                    seal_planned_chunk(&sender_session, chunk, payload).expect("seal");
                let opened =
                    open_planned_chunk(&receiver_session, chunk, &sealed, &mut checkpoint)
                        .expect("open");
                received[chunk.offset as usize..(chunk.offset + chunk.size) as usize]
                    .copy_from_slice(&opened);
            }

            // Simulate crash: persist and reload the checkpoint.
            let restored = TransferCheckpoint::from_json(
                &checkpoint.to_json().expect("serialize"),
            )
            .expect("restore");
            let mut checkpoint = restored;
            let resume = checkpoint.resume_plan().expect("resume plan");
            assert!(!resume.missing_chunks.is_empty());

            // Second attempt: send only the missing chunks.
            for index in resume.missing_chunks {
                let chunk = plan.chunks[index as usize];
                let payload =
                    &file[chunk.offset as usize..(chunk.offset + chunk.size) as usize];
                let sealed =
                    seal_planned_chunk(&sender_session, &chunk, payload).expect("seal");
                let opened =
                    open_planned_chunk(&receiver_session, &chunk, &sealed, &mut checkpoint)
                        .expect("open");
                received[chunk.offset as usize..(chunk.offset + chunk.size) as usize]
                    .copy_from_slice(&opened);
            }

            assert!(checkpoint.is_complete());
            assert!(verify_final_hash(&received, &expected_hash));
            assert_eq!(received, file);
        }

        #[test]
        fn rejects_payload_that_does_not_match_plan() {
            let (sender_session, _) = sessions();
            let plan = calculate_chunks(100, 64).expect("plan");

            assert!(matches!(
                seal_planned_chunk(&sender_session, &plan.chunks[0], b"short"),
                Err(TransferError::ChunkSizeMismatch { .. })
            ));
        }

        #[test]
        fn rejects_chunk_sealed_for_other_transfer() {
            let (sender_session, receiver_session) = sessions();

            let other_context = EncryptionContext {
                sender_device_id: "sender".to_owned(),
                receiver_device_id: "receiver".to_owned(),
                transfer_id: "tx-other".to_owned(),
            };
            let (handshake, other_sender) = TransferSession::initiate(
                &StaticSecretKey::from_bytes([0x11; 32]),
                &StaticSecretKey::from_bytes([0x22; 32]).public_key(),
                &other_context,
            )
            .expect("initiate");
            let _ = (handshake, &receiver_session);

            let plan = calculate_chunks(5, 64).expect("plan");
            let sealed =
                seal_planned_chunk(&other_sender, &plan.chunks[0], b"hello").expect("seal");

            let mut checkpoint = TransferCheckpoint::new(
                "tx-pipeline-01",
                5,
                64,
                1,
                "f7ca7c61125005f4ec9b024022a08bc887908206357c8ebf29595d738f6b14a4",
            )
            .expect("checkpoint");
            assert!(matches!(
                open_planned_chunk(&receiver_session, &plan.chunks[0], &sealed, &mut checkpoint),
                Err(TransferError::Encryption(_))
            ));
            assert!(checkpoint.completed_chunks.is_empty());
        }
    }
}
