using Microsoft.Win32;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace ItamarOS.Native.Windows;

public partial class MainWindow : Window
{
    private readonly string[] _allApps =
        ["Files", "Player", "Games", "Settings", "Notes", "System Info"];
    private readonly Dictionary<string, FrameworkElement> _running = new();
    private readonly string _settingsPath =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                     "ItamarOS", "native-demo-settings.json");
    private List<string> _pins = ["Files", "Player", "Games", "Settings"];
    private string? _active;
    private string _notes = "";
    private int _bestScore;

    public MainWindow()
    {
        InitializeComponent();
        LoadState();
        ShowStartPage();
        UpdateTaskbar();
    }

    private void LoadState()
    {
        try {
            if (!File.Exists(_settingsPath)) return;
            var data = JsonSerializer.Deserialize<AppState>(File.ReadAllText(_settingsPath));
            if (data is null) return;
            _pins = (data.Pinned ?? []).Where(_allApps.Contains).Distinct().ToList();
            _notes = data.Notes ?? "";
            _bestScore = Math.Max(0, data.BestScore);
        } catch { /* Malformed settings never prevent launching the demo. */ }
    }

    private void SaveState()
    {
        try {
            Directory.CreateDirectory(Path.GetDirectoryName(_settingsPath)!);
            File.WriteAllText(_settingsPath, JsonSerializer.Serialize(new AppState {
                Pinned = _pins, Notes = _notes, BestScore = _bestScore
            }));
        } catch { /* A read-only profile may be in use. */ }
    }

    private record AppState {
        public List<string>? Pinned { get; init; }
        public string? Notes { get; init; }
        public int BestScore { get; init; }
    }

    private Button Button(string text, Action action) {
        var b = new Button {
            Content = text, Padding = new Thickness(15, 9),
            Margin = new Thickness(6), MinHeight = 38
        };
        b.Click += (_, _) => action();
        return b;
    }

    private TextBlock Text(string t, int size=16) =>
        new() { Text=t, FontSize=size, Margin=new Thickness(10), Foreground=Brushes.White,
                TextWrapping=TextWrapping.Wrap };

    private void ShowStart(object sender, RoutedEventArgs e) => ShowStartPage();

    private void ShowStartPage()
    {
        _active = null;
        var panel = new WrapPanel { Orientation=Orientation.Horizontal };
        foreach (string id in _allApps) {
            var tile=Button(id, () => OpenApp(id));
            tile.MinWidth=150; tile.MinHeight=85;
            panel.Children.Add(tile);
        }
        AppContent.Content = new StackPanel {
            Children = { Text("ItamarOS Native Demo",30),
                         Text("Windows-native WPF application. No Electron or WebView. " +
                              "This does not replace your Windows operating system."), panel }
        };
        UpdateTaskbar();
    }

    private void OpenApp(string id)
    {
        if (!_allApps.Contains(id)) return;
        if (!_running.TryGetValue(id, out FrameworkElement? panel)) {
            panel = CreateView(id);
            _running[id] = panel;
        }
        AppContent.Content = panel;
        _active = id;
        UpdateTaskbar();
    }

    private FrameworkElement CreateView(string id) => id switch {
        "Files" => CreateFiles(),
        "Player" => CreatePlayer(),
        "Games" => CreateGames(),
        "Settings" => CreateSettings(),
        "Notes" => CreateNotes(),
        _ => CreateSystem()
    };

    private void MinimizeCurrent(object sender, RoutedEventArgs e) {
        // Keep the view in _running until explicitly closed.
        ShowStartPage();
    }

    private void CloseCurrent(object sender, RoutedEventArgs e) {
        if (_active is { } id) {
            // Remove content before closing; it may own native media/player handles.
            AppContent.Content = null;
            _running.Remove(id);
        }
        ShowStartPage();
    }

    private void UpdateTaskbar()
    {
        if (TaskbarApps is null) return;
        TaskbarApps.Children.Clear();
        foreach (string id in _pins.Concat(_running.Keys).Distinct()) {
            var b=Button(id+(_running.ContainsKey(id)?" ●":""), () => OpenApp(id));
            b.ToolTip = _running.ContainsKey(id)?"Running (right-click to close or unpin)":"Pinned";
            b.ContextMenu = new ContextMenu();
            var pinItem = new MenuItem { Header=_pins.Contains(id)?"Unpin from taskbar":"Pin to taskbar" };
            pinItem.Click += (_, _) => { if (_pins.Contains(id)) _pins.Remove(id);
                                         else _pins.Add(id); SaveState(); UpdateTaskbar(); };
            b.ContextMenu.Items.Add(pinItem);
            if (_running.ContainsKey(id)) {
                var close = new MenuItem { Header="Close app" };
                close.Click += (_, _) => {
                    if (_active == id) AppContent.Content=null;
                    _running.Remove(id);
                    ShowStartPage();
                };
                b.ContextMenu.Items.Add(close);
            }
            TaskbarApps.Children.Add(b);
        }
    }

    private FrameworkElement CreateFiles()
    {
        var stack = new StackPanel();
        stack.Children.Add(Text("Files",27));
        stack.Children.Add(Text("Choose files explicitly. The demo does not scan your disk."));
        var files = new ListBox { MinHeight=200 };
        stack.Children.Add(Button("Select files", () => {
            var chooser = new OpenFileDialog { Multiselect = true, CheckFileExists=true };
            if (chooser.ShowDialog()==true)
                foreach (var file in chooser.FileNames)
                    files.Items.Add(Path.GetFileName(file));
        }));
        stack.Children.Add(files);
        return stack;
    }

    private FrameworkElement CreatePlayer()
    {
        var panel=new StackPanel();
        var media=new MediaElement { LoadedBehavior=MediaState.Manual,
                                     UnloadedBehavior=MediaState.Close,
                                     Height=330, Stretch=Stretch.Uniform };
        panel.Children.Add(Text("ItamarOS Player",27));
        panel.Children.Add(Text("WPF native media playback; available codecs depend on Windows."));
        panel.Children.Add(media);
        var controls=new WrapPanel();
        controls.Children.Add(Button("Choose media",()=>{
            var chooser=new OpenFileDialog {
                Filter="Media|*.mp4;*.wmv;*.mp3;*.wav;*.wma|All files|*.*"
            };
            if (chooser.ShowDialog()==true) {
                media.Source=new Uri(chooser.FileName);
                media.Play();
            }
        }));
        controls.Children.Add(Button("Play",media.Play));
        controls.Children.Add(Button("Pause",media.Pause));
        controls.Children.Add(Button("Stop",media.Stop));
        panel.Children.Add(controls);
        return panel;
    }

    private FrameworkElement CreateGames()
    {
        var stack=new StackPanel();
        int target=Random.Shared.Next(1,21);
        int guess=10;
        var result=Text("Guess a number from 1 to 20.");
        var value=Text("Guess: 10",19);
        var best=Text($"Best score: {_bestScore}");
        stack.Children.Add(Text("Native Number Guess",27));
        stack.Children.Add(result);
        var controls=new WrapPanel();
        controls.Children.Add(Button("−",()=> {guess=Math.Max(1,guess-1);value.Text=$"Guess: {guess}";}));
        controls.Children.Add(value);
        controls.Children.Add(Button("+",()=> {guess=Math.Min(20,guess+1);value.Text=$"Guess: {guess}";}));
        controls.Children.Add(Button("Guess!",()=>{
            if (guess==target) {
                _bestScore++;
                target=Random.Shared.Next(1,21);
                result.Text="Correct! New number selected.";
                best.Text=$"Best score: {_bestScore}";
                SaveState();
            } else result.Text=guess<target?"Higher!":"Lower!";
        }));
        stack.Children.Add(controls);
        stack.Children.Add(best);
        return stack;
    }

    private FrameworkElement CreateNotes()
    {
        var field=new TextBox { Text=_notes, AcceptsReturn=true,
                                TextWrapping=TextWrapping.Wrap, MinHeight=380 };
        field.TextChanged+=(_,_) => {_notes=field.Text;SaveState();};
        return new StackPanel { Children={Text("Native Notes",27),field} };
    }

    private FrameworkElement CreateSystem()
    {
        return new StackPanel { Children={
            Text("System Information",27),
            Text($"Windows host: {Environment.OSVersion}"),
            Text($"Computer name: {Environment.MachineName}"),
            Text($"Logical processors: {Environment.ProcessorCount}"),
            Text("For full ItamarOS Linux hardware settings, a verified native Linux ISO is required.")
        }};
    }

    private FrameworkElement CreateSettings()
    {
        var stack=new StackPanel();
        stack.Children.Add(Text("System Settings",27));
        stack.Children.Add(Text("These buttons open the genuine Windows host settings; they do not change a simulated OS."));
        var mappings = new (string Name, string Uri)[] {
            ("Display & Brightness", "ms-settings:display"),
            ("Sound & Microphone", "ms-settings:sound"),
            ("Wi-Fi & Ethernet", "ms-settings:network"),
            ("Bluetooth & Devices", "ms-settings:bluetooth"),
            ("Printers & Scanners", "ms-settings:printers"),
            ("Apps & Storage", "ms-settings:appsfeatures"),
            ("Date & Time", "ms-settings:dateandtime"),
            ("Language & Region", "ms-settings:regionlanguage"),
            ("Accounts", "ms-settings:yourinfo"),
            ("Personalization", "ms-settings:personalization"),
            ("Accessibility", "ms-settings:easeofaccess"),
            ("Privacy", "ms-settings:privacy"),
            ("Windows Updates", "ms-settings:windowsupdate")
        };
        foreach (var category in mappings) {
            stack.Children.Add(Button(category.Name,()=> {
                try { Process.Start(new ProcessStartInfo(category.Uri) { UseShellExecute=true }); }
                catch { MessageBox.Show("Windows Settings could not open this section."); }
            }));
        }
        stack.Children.Add(Button("Restore default taskbar pins",()=> {
            _pins=["Files","Player","Games","Settings"];SaveState();UpdateTaskbar();
        }));
        return new ScrollViewer { Content=stack,
            VerticalScrollBarVisibility=ScrollBarVisibility.Auto };
    }
}
