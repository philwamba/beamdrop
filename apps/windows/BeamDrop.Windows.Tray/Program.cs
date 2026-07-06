using System.Diagnostics;
using System.Windows.Forms;

namespace BeamDrop.Windows.Tray;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new BeamDropTrayContext());
    }
}

public sealed class BeamDropTrayContext : ApplicationContext
{
    private readonly NotifyIcon _notifyIcon;
    private bool _clipboardPaused;

    public BeamDropTrayContext()
    {
        _notifyIcon = new NotifyIcon
        {
            Text = "BeamDrop",
            Icon = SystemIcons.Application,
            ContextMenuStrip = BuildMenu(),
            Visible = true
        };
        _notifyIcon.DoubleClick += (_, _) => OpenBeamDrop();
    }

    private ContextMenuStrip BuildMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add("Open BeamDrop", null, (_, _) => OpenBeamDrop());

        var sendClipboard = new ToolStripMenuItem("Send Clipboard To");
        sendClipboard.DropDownItems.Add("No trusted devices", null, (_, _) => ShowUnavailable("Pair a trusted device before sending clipboard content."));
        menu.Items.Add(sendClipboard);

        var sendFile = new ToolStripMenuItem("Send File To");
        sendFile.DropDownItems.Add("No trusted devices", null, (_, _) => ShowUnavailable("Pair a trusted device before sending files."));
        menu.Items.Add(sendFile);

        menu.Items.Add("Nearby Devices", null, (_, _) => OpenBeamDrop("nearby"));
        menu.Items.Add(BuildPauseClipboardItem());
        menu.Items.Add("Settings", null, (_, _) => OpenBeamDrop("settings"));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => Quit());
        return menu;
    }

    private ToolStripMenuItem BuildPauseClipboardItem()
    {
        var item = new ToolStripMenuItem("Pause Clipboard Sharing")
        {
            CheckOnClick = true,
            Checked = _clipboardPaused
        };
        item.CheckedChanged += (_, _) => _clipboardPaused = item.Checked;
        return item;
    }

    private static void OpenBeamDrop(string? route = null)
    {
        var argument = route is null ? string.Empty : $"beamdrop://{route}";
        Process.Start(new ProcessStartInfo
        {
            FileName = "BeamDrop.Windows.App.exe",
            Arguments = argument,
            UseShellExecute = true
        });
    }

    private static void ShowUnavailable(string message) =>
        MessageBox.Show(message, "BeamDrop", MessageBoxButtons.OK, MessageBoxIcon.Information);

    private void Quit()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        ExitThread();
    }
}
