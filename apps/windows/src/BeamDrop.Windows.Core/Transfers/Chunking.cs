namespace BeamDrop.Windows.Core.Transfers;

public static class ChunkCalculator
{
    public static long TotalChunks(long fileSizeBytes, int chunkSizeBytes = BeamDropProtocol.DefaultChunkSizeBytes)
    {
        if (fileSizeBytes < 0) throw new ArgumentOutOfRangeException(nameof(fileSizeBytes));
        if (chunkSizeBytes <= 0) throw new ArgumentOutOfRangeException(nameof(chunkSizeBytes));
        if (fileSizeBytes == 0) return 1;
        return ((fileSizeBytes - 1) / chunkSizeBytes) + 1;
    }

    public static ChunkPlan Plan(long fileSizeBytes, int chunkSizeBytes = BeamDropProtocol.DefaultChunkSizeBytes)
    {
        var totalChunks = TotalChunks(fileSizeBytes, chunkSizeBytes);
        var chunks = new List<ChunkMetadata>((int)Math.Min(totalChunks, int.MaxValue));
        for (var index = 0L; index < totalChunks; index++)
        {
            var offset = index * chunkSizeBytes;
            var remaining = Math.Max(0, fileSizeBytes - offset);
            var size = fileSizeBytes == 0 ? 0 : (int)Math.Min(chunkSizeBytes, remaining);
            chunks.Add(new ChunkMetadata(index, offset, size));
        }
        return new ChunkPlan(fileSizeBytes, chunkSizeBytes, chunks);
    }
}

public static class ResumePlanner
{
    public static ResumePlan Plan(string transferId, long totalChunks, IEnumerable<long> completedChunks)
    {
        if (string.IsNullOrWhiteSpace(transferId)) throw new ArgumentException("Transfer id is required.", nameof(transferId));
        if (totalChunks <= 0) throw new ArgumentOutOfRangeException(nameof(totalChunks));
        var completed = completedChunks.ToHashSet();
        foreach (var chunk in completed)
        {
            if (chunk < 0 || chunk >= totalChunks) throw new InvalidOperationException($"Completed chunk {chunk} is out of range.");
        }
        var missing = Enumerable.Range(0, (int)totalChunks).Select(value => (long)value).Where(chunk => !completed.Contains(chunk)).ToList();
        return new ResumePlan(transferId, totalChunks, completed, missing);
    }
}
