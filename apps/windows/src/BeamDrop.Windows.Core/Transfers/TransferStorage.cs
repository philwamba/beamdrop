namespace BeamDrop.Windows.Core.Transfers;

public interface ITransferHistoryStore
{
    IReadOnlyList<TransferHistoryRecord> List();
    void Upsert(TransferHistoryRecord record);
}

public sealed class InMemoryTransferHistoryStore : ITransferHistoryStore
{
    private readonly Dictionary<string, TransferHistoryRecord> _records = new(StringComparer.Ordinal);

    public IReadOnlyList<TransferHistoryRecord> List() => _records.Values.OrderByDescending(record => record.CreatedAt).ToList();

    public void Upsert(TransferHistoryRecord record) => _records[record.TransferId] = record;
}

public interface IReceiveTarget
{
    Stream OpenWrite();
    Stream OpenReadForVerification();
    string CommitVerified();
    void Discard();
}

public interface IReceiveTargetFactory
{
    IReceiveTarget Create(TransferManifest manifest);
}

public sealed class DownloadsReceiveTargetFactory : IReceiveTargetFactory
{
    private readonly string _downloadsPath;
    private readonly string _stagingPath;

    public DownloadsReceiveTargetFactory(string? downloadsPath = null, string? stagingPath = null)
    {
        _downloadsPath = downloadsPath ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
        _stagingPath = stagingPath ?? Path.Combine(Path.GetTempPath(), "BeamDrop", "Staging");
    }

    public IReceiveTarget Create(TransferManifest manifest)
    {
        Directory.CreateDirectory(_downloadsPath);
        Directory.CreateDirectory(_stagingPath);
        var safeName = MakeSafeFileName(manifest.FileName);
        var staging = Path.Combine(_stagingPath, $"{manifest.TransferId}.part");
        var destination = UniquePath(Path.Combine(_downloadsPath, safeName));
        return new FileReceiveTarget(staging, destination);
    }

    private static string MakeSafeFileName(string fileName)
    {
        var invalid = Path.GetInvalidFileNameChars().ToHashSet();
        var safe = new string(fileName.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray()).Trim();
        return string.IsNullOrWhiteSpace(safe) ? "BeamDrop file" : safe;
    }

    private static string UniquePath(string path)
    {
        if (!File.Exists(path)) return path;
        var directory = Path.GetDirectoryName(path)!;
        var name = Path.GetFileNameWithoutExtension(path);
        var extension = Path.GetExtension(path);
        var counter = 1;
        string candidate;
        do
        {
            candidate = Path.Combine(directory, $"{name}-{counter}{extension}");
            counter++;
        } while (File.Exists(candidate));
        return candidate;
    }
}

public sealed class FileReceiveTarget : IReceiveTarget
{
    private readonly string _stagingPath;
    private readonly string _destinationPath;

    public FileReceiveTarget(string stagingPath, string destinationPath)
    {
        _stagingPath = stagingPath;
        _destinationPath = destinationPath;
    }

    public Stream OpenWrite() => File.Create(_stagingPath);

    public Stream OpenReadForVerification() => File.OpenRead(_stagingPath);

    public string CommitVerified()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_destinationPath)!);
        if (File.Exists(_destinationPath)) File.Delete(_destinationPath);
        File.Move(_stagingPath, _destinationPath);
        return _destinationPath;
    }

    public void Discard()
    {
        if (File.Exists(_stagingPath)) File.Delete(_stagingPath);
    }
}
