use beamdrop_crypto::verify_sha256;
use std::collections::BTreeSet;
use std::error::Error;
use std::fmt;

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
}
