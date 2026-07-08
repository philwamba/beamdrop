//! Durable resume state for interrupted transfers.
//!
//! A [`TransferCheckpoint`] is written by the receiver after every verified
//! chunk and reloaded after a crash or disconnect. The serialized form is the
//! cross-platform wire/disk contract: platforms persist it as JSON next to the
//! partial file (or in their transfer database) and exchange it during the
//! resume handshake so the sender only retransmits missing chunks.

use crate::{plan_resume, ResumePlan, TransferError};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

pub const CHECKPOINT_FORMAT_VERSION: u32 = 1;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransferCheckpoint {
    pub format_version: u32,
    pub transfer_id: String,
    pub file_size: u64,
    pub chunk_size: u64,
    pub total_chunks: u64,
    pub expected_sha256: String,
    pub completed_chunks: BTreeSet<u64>,
}

impl TransferCheckpoint {
    pub fn new(
        transfer_id: impl Into<String>,
        file_size: u64,
        chunk_size: u64,
        total_chunks: u64,
        expected_sha256: impl Into<String>,
    ) -> Result<Self, TransferError> {
        let transfer_id = transfer_id.into();
        if transfer_id.trim().is_empty() {
            return Err(TransferError::MissingTransferId);
        }
        if chunk_size == 0 {
            return Err(TransferError::InvalidChunkSize);
        }
        let expected_sha256 = expected_sha256.into();
        if !is_sha256_hex(&expected_sha256) {
            return Err(TransferError::InvalidExpectedHash);
        }
        Ok(Self {
            format_version: CHECKPOINT_FORMAT_VERSION,
            transfer_id,
            file_size,
            chunk_size,
            total_chunks,
            expected_sha256,
            completed_chunks: BTreeSet::new(),
        })
    }

    /// Marks a chunk as durably received and verified.
    pub fn record_chunk(&mut self, chunk_index: u64) -> Result<(), TransferError> {
        if chunk_index >= self.total_chunks {
            return Err(TransferError::CompletedChunkOutOfRange {
                chunk_index,
                total_chunks: self.total_chunks,
            });
        }
        self.completed_chunks.insert(chunk_index);
        Ok(())
    }

    pub fn is_complete(&self) -> bool {
        self.completed_chunks.len() as u64 == self.total_chunks
    }

    pub fn bytes_completed(&self) -> u64 {
        self.completed_chunks
            .iter()
            .map(|index| {
                let offset = index * self.chunk_size;
                self.file_size.saturating_sub(offset).min(self.chunk_size)
            })
            .sum()
    }

    /// Builds the resume plan the sender needs: which chunks are still missing.
    pub fn resume_plan(&self) -> Result<ResumePlan, TransferError> {
        plan_resume(
            self.transfer_id.clone(),
            self.total_chunks,
            self.completed_chunks.iter().copied(),
        )
    }

    pub fn to_json(&self) -> Result<String, TransferError> {
        serde_json::to_string(self).map_err(|_| TransferError::CheckpointSerializationFailed)
    }

    /// Loads and revalidates a checkpoint. Every invariant is re-checked so a
    /// corrupted or tampered file on disk cannot smuggle in an inconsistent
    /// resume state.
    pub fn from_json(json: &str) -> Result<Self, TransferError> {
        let checkpoint: Self =
            serde_json::from_str(json).map_err(|_| TransferError::CheckpointParseFailed)?;
        if checkpoint.format_version != CHECKPOINT_FORMAT_VERSION {
            return Err(TransferError::UnsupportedCheckpointVersion(
                checkpoint.format_version,
            ));
        }
        if checkpoint.transfer_id.trim().is_empty() {
            return Err(TransferError::MissingTransferId);
        }
        if checkpoint.chunk_size == 0 {
            return Err(TransferError::InvalidChunkSize);
        }
        if !is_sha256_hex(&checkpoint.expected_sha256) {
            return Err(TransferError::InvalidExpectedHash);
        }
        if let Some(max) = checkpoint.completed_chunks.iter().next_back() {
            if *max >= checkpoint.total_chunks {
                return Err(TransferError::CompletedChunkOutOfRange {
                    chunk_index: *max,
                    total_chunks: checkpoint.total_chunks,
                });
            }
        }
        Ok(checkpoint)
    }
}

fn is_sha256_hex(value: &str) -> bool {
    value.len() == 64 && value.bytes().all(|b| b.is_ascii_hexdigit())
}

#[cfg(test)]
mod tests {
    use super::*;

    const HASH: &str = "f7ca7c61125005f4ec9b024022a08bc887908206357c8ebf29595d738f6b14a4";

    fn checkpoint() -> TransferCheckpoint {
        TransferCheckpoint::new("tx-resume-01", 10 * 1024 * 1024, 4 * 1024 * 1024, 3, HASH)
            .expect("checkpoint")
    }

    #[test]
    fn records_progress_and_reports_completion() {
        let mut cp = checkpoint();
        assert!(!cp.is_complete());

        cp.record_chunk(0).expect("record");
        cp.record_chunk(2).expect("record");
        assert_eq!(cp.resume_plan().expect("plan").missing_chunks, vec![1]);
        assert!(!cp.is_complete());

        cp.record_chunk(1).expect("record");
        assert!(cp.is_complete());
        assert_eq!(cp.bytes_completed(), 10 * 1024 * 1024);
    }

    #[test]
    fn recording_same_chunk_twice_is_idempotent() {
        let mut cp = checkpoint();
        cp.record_chunk(1).expect("record");
        cp.record_chunk(1).expect("record");
        assert_eq!(cp.completed_chunks.len(), 1);
    }

    #[test]
    fn rejects_out_of_range_chunk() {
        let mut cp = checkpoint();
        assert!(matches!(
            cp.record_chunk(3),
            Err(TransferError::CompletedChunkOutOfRange { .. })
        ));
    }

    #[test]
    fn survives_json_round_trip() {
        let mut cp = checkpoint();
        cp.record_chunk(0).expect("record");
        cp.record_chunk(2).expect("record");

        let json = cp.to_json().expect("serialize");
        let restored = TransferCheckpoint::from_json(&json).expect("parse");

        assert_eq!(restored, cp);
        assert_eq!(restored.resume_plan().expect("plan").missing_chunks, vec![1]);
    }

    #[test]
    fn rejects_corrupted_checkpoint_on_load() {
        assert_eq!(
            TransferCheckpoint::from_json("not json"),
            Err(TransferError::CheckpointParseFailed)
        );

        let mut cp = checkpoint();
        cp.record_chunk(0).expect("record");
        let json = cp
            .to_json()
            .expect("serialize")
            .replace("\"totalChunks\":3", "\"totalChunks\":0");
        assert!(matches!(
            TransferCheckpoint::from_json(&json),
            Err(TransferError::CompletedChunkOutOfRange { .. })
        ));
    }

    #[test]
    fn rejects_unsupported_version() {
        let json = checkpoint()
            .to_json()
            .expect("serialize")
            .replace("\"formatVersion\":1", "\"formatVersion\":99");
        assert_eq!(
            TransferCheckpoint::from_json(&json),
            Err(TransferError::UnsupportedCheckpointVersion(99))
        );
    }

    #[test]
    fn rejects_invalid_hash() {
        assert_eq!(
            TransferCheckpoint::new("tx", 1, 1, 1, "zz"),
            Err(TransferError::InvalidExpectedHash)
        );
    }
}
