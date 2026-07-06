using BeamDrop.Windows.Clipboard;
using BeamDrop.Windows.Persistence;
using BeamDrop.Windows.Security;
using BeamDrop.Windows.Transfer;

var tests = new (string Name, Action Test)[]
{
    ("settings repository stores and updates values", SettingsRepositoryStoresValues),
    ("SQLite schema creates required BeamDrop tables", SchemaCreatesRequiredTables),
    ("trusted peer model allows matching trusted key only", TrustedPeerAllowsMatchingTrustedKeyOnly),
    ("revoked peer cannot transfer", RevokedPeerCannotTransfer),
    ("clipboard policy blocks non user initiated manual send", ClipboardPolicyBlocksSilentManualSend),
    ("clipboard policy allows user initiated trusted send", ClipboardPolicyAllowsUserInitiatedTrustedSend),
    ("transfer progress clamps percent", TransferProgressClampsPercent),
};

var failed = 0;
foreach (var (name, test) in tests)
{
    try
    {
        test();
        Console.WriteLine($"PASS {name}");
    }
    catch (Exception ex)
    {
        failed++;
        Console.Error.WriteLine($"FAIL {name}: {ex.Message}");
    }
}

if (failed > 0)
{
    Environment.Exit(1);
}

static void SettingsRepositoryStoresValues()
{
    var repository = new InMemorySettingsRepository();
    repository.Set("theme", "dark", DateTimeOffset.UnixEpoch);
    repository.Set("theme", "light", DateTimeOffset.UnixEpoch.AddSeconds(1));

    AssertEqual("light", repository.Get("theme"));
    AssertEqual(1, repository.List().Count);
}

static void SchemaCreatesRequiredTables()
{
    var sql = string.Join("\n", BeamDropSchema.CreateStatements);
    AssertContains("CREATE TABLE IF NOT EXISTS trusted_peers", sql);
    AssertContains("CREATE TABLE IF NOT EXISTS transfers", sql);
    AssertContains("CREATE TABLE IF NOT EXISTS settings", sql);
    AssertContains("CREATE TABLE IF NOT EXISTS audit_events", sql);
}

static void TrustedPeerAllowsMatchingTrustedKeyOnly()
{
    var peer = TrustedPeer.CreateTrusted("device-1", "Surface Laptop", DevicePlatform.Windows, "public-key", DateTimeOffset.UnixEpoch);

    AssertTrue(peer.CanTransfer("public-key"), "trusted matching key should transfer");
    AssertFalse(peer.CanTransfer("different-key"), "mismatched public key should not transfer");
    AssertEqual(TrustState.Trusted, peer.TrustState);
}

static void RevokedPeerCannotTransfer()
{
    var repository = new InMemoryTrustedPeerRepository();
    var peer = TrustedPeer.CreateTrusted("device-1", "Surface Laptop", DevicePlatform.Windows, "public-key", DateTimeOffset.UnixEpoch);
    repository.Upsert(peer);

    AssertTrue(repository.Revoke("device-1", DateTimeOffset.UnixEpoch.AddMinutes(1)), "revoke should find peer");
    var revoked = repository.Get("device-1")!;

    AssertEqual(TrustState.Revoked, revoked.TrustState);
    AssertFalse(revoked.CanTransfer("public-key"), "revoked peer should not transfer");
}

static void ClipboardPolicyBlocksSilentManualSend()
{
    var decision = new ClipboardPolicy(
        Mode: ClipboardSharingMode.ManualOnly,
        IsPaused: false,
        HasTrustedTarget: true,
        UserInitiated: false,
        ContainsSensitiveContent: false).EvaluateSend();

    AssertEqual(ClipboardPolicyDecisionKind.RequiresUserAction, decision.Kind);
}

static void ClipboardPolicyAllowsUserInitiatedTrustedSend()
{
    var decision = new ClipboardPolicy(
        Mode: ClipboardSharingMode.ManualOnly,
        IsPaused: false,
        HasTrustedTarget: true,
        UserInitiated: true,
        ContainsSensitiveContent: false).EvaluateSend();

    AssertEqual(ClipboardPolicyDecisionKind.Allowed, decision.Kind);
}

static void TransferProgressClampsPercent()
{
    var progress = new TransferProgress("tx-1", "photo.jpg", 100, 130, 10, TransferStatus.Transferring);
    AssertEqual(100, progress.Percent);
}

static void AssertTrue(bool value, string message)
{
    if (!value)
    {
        throw new InvalidOperationException(message);
    }
}

static void AssertFalse(bool value, string message)
{
    if (value)
    {
        throw new InvalidOperationException(message);
    }
}

static void AssertEqual<T>(T expected, T actual)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
    {
        throw new InvalidOperationException($"Expected {expected}, got {actual}.");
    }
}

static void AssertContains(string expected, string actual)
{
    if (!actual.Contains(expected, StringComparison.Ordinal))
    {
        throw new InvalidOperationException($"Expected SQL to contain '{expected}'.");
    }
}
