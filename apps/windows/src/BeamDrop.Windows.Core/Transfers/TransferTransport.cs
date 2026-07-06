namespace BeamDrop.Windows.Core.Transfers;

public interface ITransferTransport
{
    Task SendAsync(TransferManifest manifest, Stream payload, IProgress<TransferProgress> progress, CancellationToken cancellationToken);
}

public sealed class StreamCopyTransferTransport : ITransferTransport
{
    private readonly Stream _sink;

    public StreamCopyTransferTransport(Stream sink)
    {
        _sink = sink;
    }

    public async Task SendAsync(TransferManifest manifest, Stream payload, IProgress<TransferProgress> progress, CancellationToken cancellationToken)
    {
        var started = DateTimeOffset.UtcNow;
        var buffer = new byte[manifest.ChunkSizeBytes];
        var transferred = 0L;
        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var read = await payload.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
            if (read == 0) break;
            await _sink.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            transferred += read;
            var elapsedSeconds = Math.Max(1, (long)(DateTimeOffset.UtcNow - started).TotalSeconds);
            progress.Report(new TransferProgress(manifest.TransferId, manifest.ReceiverDeviceId, manifest.FileName, TransferDirection.Sent, TransferStatus.Transferring, transferred, manifest.SizeBytes, transferred / elapsedSeconds));
        }
    }
}
