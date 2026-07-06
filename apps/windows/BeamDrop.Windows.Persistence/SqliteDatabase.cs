namespace BeamDrop.Windows.Persistence;

public interface ISqliteCommandExecutor
{
    void ExecuteNonQuery(string sql);
}

public sealed class SqliteDatabaseInitializer
{
    private readonly ISqliteCommandExecutor _executor;

    public SqliteDatabaseInitializer(ISqliteCommandExecutor executor)
    {
        _executor = executor;
    }

    public void Initialize()
    {
        foreach (var statement in BeamDropSchema.CreateStatements)
        {
            _executor.ExecuteNonQuery(statement);
        }
    }
}
