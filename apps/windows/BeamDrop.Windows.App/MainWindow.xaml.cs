using BeamDrop.Windows.App.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace BeamDrop.Windows.App;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(null);
        ShellFrame.Navigate(typeof(HomePage));
    }

    private void ShellNavigation_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.IsSettingsSelected)
        {
            ShellFrame.Navigate(typeof(SettingsPage));
            return;
        }

        if (args.SelectedItem is not NavigationViewItem item || item.Tag is not string tag)
        {
            return;
        }

        ShellFrame.Navigate(tag switch
        {
            "Home" => typeof(HomePage),
            "NearbyDevices" => typeof(NearbyDevicesPage),
            "PairDevice" => typeof(PairDevicePage),
            "ScanQr" => typeof(ScanQrPage),
            "SendText" => typeof(SendTextPage),
            "SendFile" => typeof(SendFilePage),
            "TransferProgress" => typeof(TransferProgressPage),
            "History" => typeof(HistoryPage),
            "TrustedDevices" => typeof(TrustedDevicesPage),
            "ClipboardPolicy" => typeof(ClipboardPolicyPage),
            "Privacy" => typeof(PrivacyPage),
            "NetworkDiagnostics" => typeof(NetworkDiagnosticsPage),
            "About" => typeof(AboutPage),
            _ => typeof(HomePage)
        });
    }
}
