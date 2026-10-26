using System.Threading;
using System.Windows;

namespace StandUpReminder.App;

public partial class App : Application
{
    private const string MutexName = "Local\\StandUpReminder.Windows.SingleInstance";
    private Mutex? _singleInstanceMutex;
    private ApplicationController? _controller;
    private bool _ownsMutex;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _singleInstanceMutex = new Mutex(
            initiallyOwned: true,
            MutexName,
            out _ownsMutex);

        if (!_ownsMutex)
        {
            MessageBox.Show(
                "站立提醒已经在运行。请查看系统托盘。",
                "站立提醒",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
            Shutdown();
            return;
        }

        _controller = new ApplicationController();
        _controller.Start();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _controller?.Dispose();

        if (_singleInstanceMutex is not null && _ownsMutex)
        {
            _singleInstanceMutex.ReleaseMutex();
        }

        _singleInstanceMutex?.Dispose();

        base.OnExit(e);
    }
}
