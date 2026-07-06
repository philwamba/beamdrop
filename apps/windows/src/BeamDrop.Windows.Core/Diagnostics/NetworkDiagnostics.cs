using BeamDrop.Windows.Core.Discovery;

namespace BeamDrop.Windows.Core.Diagnostics;

public sealed record DiagnosticResult(
    string Status,
    IReadOnlyList<string> Findings,
    IReadOnlyList<string> RecommendedActions);

public sealed class NetworkDiagnosticsService
{
    public DiagnosticResult BuildDiscoveryDiagnostics(IReadOnlyList<DiscoveryRecord> discoveredRecords)
    {
        var findings = new List<string>
        {
            $"BeamDrop discovery service: {BeamDropProtocol.ServiceName}",
            discoveredRecords.Count == 0
                ? "No BeamDrop devices were discovered on the local network."
                : $"Discovered {discoveredRecords.Count} BeamDrop device(s)."
        };

        var actions = new List<string>
        {
            "Use Manual Connection if public or corporate Wi-Fi blocks local discovery.",
            "Confirm both devices are on the same network or reachable subnet.",
            "Allow BeamDrop through Windows Defender Firewall for private networks.",
            "If managed by IT, ask whether multicast DNS or peer-to-peer client traffic is blocked."
        };

        return new DiagnosticResult(discoveredRecords.Count == 0 ? "Discovery blocked or unavailable" : "Discovery available", findings, actions);
    }

    public DiagnosticResult BuildManualConnectionDiagnostics(ManualConnectionEndpoint endpoint)
    {
        var findings = new List<string>
        {
            $"Manual endpoint: {endpoint.HostName}:{endpoint.Port}",
            "Manual fallback does not weaken trust checks. Pairing and approval are still required."
        };
        var actions = new List<string>
        {
            "Verify the address shown on the other BeamDrop device.",
            "Check Windows Firewall if the connection times out.",
            "Avoid public Wi-Fi networks with client isolation when possible."
        };
        return new DiagnosticResult("Manual connection ready", findings, actions);
    }
}
