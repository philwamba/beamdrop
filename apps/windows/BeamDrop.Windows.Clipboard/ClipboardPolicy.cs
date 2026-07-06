namespace BeamDrop.Windows.Clipboard;

public enum ClipboardSharingMode
{
    Off,
    ManualOnly,
    WatchedWhenAppOpen
}

public enum ClipboardPolicyDecisionKind
{
    Allowed,
    Blocked,
    RequiresUserAction
}

public sealed record ClipboardPolicyDecision(
    ClipboardPolicyDecisionKind Kind,
    string Message);

public sealed record ClipboardPolicy(
    ClipboardSharingMode Mode,
    bool IsPaused,
    bool HasTrustedTarget,
    bool UserInitiated,
    bool ContainsSensitiveContent)
{
    public ClipboardPolicyDecision EvaluateSend()
    {
        if (IsPaused)
        {
            return new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.Blocked, "Clipboard sharing is paused.");
        }

        if (!HasTrustedTarget)
        {
            return new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.Blocked, "Choose a trusted device before sending clipboard content.");
        }

        if (ContainsSensitiveContent)
        {
            return new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.RequiresUserAction, "Review sensitive clipboard content before sending.");
        }

        return Mode switch
        {
            ClipboardSharingMode.Off => new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.Blocked, "Clipboard sharing is off."),
            ClipboardSharingMode.ManualOnly when !UserInitiated => new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.RequiresUserAction, "Clipboard sends must be user initiated."),
            ClipboardSharingMode.ManualOnly => new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.Allowed, "Clipboard send allowed."),
            ClipboardSharingMode.WatchedWhenAppOpen when UserInitiated => new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.Allowed, "Clipboard send allowed."),
            ClipboardSharingMode.WatchedWhenAppOpen => new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.RequiresUserAction, "Confirm watched clipboard send."),
            _ => new ClipboardPolicyDecision(ClipboardPolicyDecisionKind.Blocked, "Clipboard sharing is unavailable.")
        };
    }
}
