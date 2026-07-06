namespace BeamDrop.Windows.Persistence;

public static class BeamDropSchema
{
    public const int CurrentVersion = 1;

    public static IReadOnlyList<string> CreateStatements { get; } = new[]
    {
        """
        CREATE TABLE IF NOT EXISTS trusted_peers (
            device_id TEXT PRIMARY KEY NOT NULL,
            display_name TEXT NOT NULL,
            platform TEXT NOT NULL,
            public_key TEXT NOT NULL,
            fingerprint TEXT NOT NULL,
            trust_state TEXT NOT NULL,
            trusted_at TEXT NULL,
            revoked_at TEXT NULL,
            last_seen_at TEXT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS transfers (
            transfer_id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL,
            status TEXT NOT NULL,
            peer_device_id TEXT NOT NULL,
            peer_display_name TEXT NOT NULL,
            total_bytes INTEGER NOT NULL,
            bytes_transferred INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            completed_at TEXT NULL,
            error_message TEXT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS audit_events (
            event_id TEXT PRIMARY KEY NOT NULL,
            category TEXT NOT NULL,
            message TEXT NOT NULL,
            created_at TEXT NOT NULL,
            peer_device_id TEXT NULL
        );
        """
    };
}
