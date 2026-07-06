package com.beamdrop.android.core.transfer

interface TransferHistoryStore {
    fun list(): List<TransferHistoryRecord>
    fun upsert(record: TransferHistoryRecord)
}

class InMemoryTransferHistoryStore(
    initialRecords: List<TransferHistoryRecord> = emptyList(),
) : TransferHistoryStore {
    private val records = LinkedHashMap<String, TransferHistoryRecord>()

    init {
        initialRecords.forEach { records[it.transferId] = it }
    }

    override fun list(): List<TransferHistoryRecord> =
        records.values.sortedByDescending { it.createdAtEpochMillis }

    override fun upsert(record: TransferHistoryRecord) {
        records[record.transferId] = record
    }
}

