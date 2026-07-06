using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using BeamDrop.Windows.Core.Discovery;
using BeamDrop.Windows.Core.Peers;

namespace BeamDrop.Windows.Core.Transfers;

public sealed class TcpClientTransferTransport : ITransferTransport
{
    private readonly ManualConnectionEndpoint _endpoint;

    public TcpClientTransferTransport(ManualConnectionEndpoint endpoint)
    {
        _endpoint = endpoint;
    }

    public async Task SendAsync(TransferManifest manifest, Stream payload, IProgress<TransferProgress> progress, CancellationToken cancellationToken)
    {
        using var client = new TcpClient();
        await client.ConnectAsync(_endpoint.HostName, _endpoint.Port, cancellationToken);
        await using var network = client.GetStream();

        var header = TransferEnvelopeCodec.Encode(manifest);
        var headerBytes = Encoding.UTF8.GetBytes(header + "\n");
        await network.WriteAsync(headerBytes.AsMemory(0, headerBytes.Length), cancellationToken);

        var started = DateTimeOffset.UtcNow;
        var buffer = new byte[manifest.ChunkSizeBytes];
        var transferred = 0L;
        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var read = await payload.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
            if (read == 0) break;
            await network.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            transferred += read;
            var elapsedSeconds = Math.Max(1, (long)(DateTimeOffset.UtcNow - started).TotalSeconds);
            progress.Report(new TransferProgress(manifest.TransferId, _endpoint.HostName, manifest.FileName, TransferDirection.Sent, TransferStatus.Transferring, transferred, manifest.SizeBytes, transferred / elapsedSeconds));
        }
    }
}

public sealed class TcpIncomingTransferServer
{
    private readonly TransferManager _transferManager;
    private readonly Func<TransferManifest, TransferPeer> _senderResolver;

    public TcpIncomingTransferServer(TransferManager transferManager, Func<TransferManifest, TransferPeer> senderResolver)
    {
        _transferManager = transferManager;
        _senderResolver = senderResolver;
    }

    public async Task RunOnceAsync(int port, CancellationToken cancellationToken)
    {
        var listener = new TcpListener(IPAddress.Any, port);
        listener.Start();
        try
        {
            using var client = await listener.AcceptTcpClientAsync(cancellationToken);
            await using var stream = client.GetStream();
            var manifest = await ReadManifestAsync(stream, cancellationToken);
            var sender = _senderResolver(manifest);
            var request = new IncomingTransferRequest(manifest, sender);
            if (manifest.Kind is TransferKind.Text or TransferKind.Url or TransferKind.ClipboardText)
            {
                using var memory = new MemoryStream();
                await stream.CopyToAsync(memory, cancellationToken);
                var text = Encoding.UTF8.GetString(memory.ToArray());
                await _transferManager.ReceiveTextAsync(request, text, cancellationToken);
            }
            else
            {
                await _transferManager.ReceiveFileAsync(request, stream, cancellationToken);
            }
        }
        finally
        {
            listener.Stop();
        }
    }

    private static async Task<TransferManifest> ReadManifestAsync(Stream stream, CancellationToken cancellationToken)
    {
        var bytes = new List<byte>();
        var buffer = new byte[1];
        while (true)
        {
            var read = await stream.ReadAsync(buffer.AsMemory(0, 1), cancellationToken);
            if (read == 0) throw new EndOfStreamException("Connection closed before transfer manifest.");
            if (buffer[0] == (byte)'\n') break;
            bytes.Add(buffer[0]);
            if (bytes.Count > 64 * 1024) throw new InvalidOperationException("Transfer manifest is too large.");
        }

        var json = Encoding.UTF8.GetString(bytes.ToArray());
        return TransferEnvelopeCodec.Decode(json);
    }
}
