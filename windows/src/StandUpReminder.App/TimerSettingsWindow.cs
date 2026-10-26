using System.Windows;
using System.Windows.Controls;
using StandUpReminder.Core;

namespace StandUpReminder.App;

internal sealed class TimerSettingsWindow : Window
{
    private static readonly int[] WorkOptions =
        [15, 25, 30, 45, 50, 60, 75, 90, 120];
    private static readonly int[] StandingOptions =
        [1, 3, 5, 10, 15, 20];

    private readonly ComboBox _workCombo = new();
    private readonly ComboBox _standingCombo = new();

    public TimerSettingsWindow(ReminderConfiguration configuration)
    {
        Title = "计时设置";
        Width = 420;
        Height = 280;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;

        Populate(_workCombo, WorkOptions, configuration.WorkDuration);
        Populate(_standingCombo, StandingOptions, configuration.StandingDuration);

        var grid = new Grid { Margin = new Thickness(28) };
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition());
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition());

        var description = new TextBlock
        {
            Text = "保存后会保留本轮已经工作的时长；如果新的工作时长已经到期，会立即开始休息。",
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 20)
        };
        Grid.SetRow(description, 0);
        Grid.SetColumnSpan(description, 2);
        grid.Children.Add(description);

        AddLabeledControl(grid, "工作时长", _workCombo, 1);
        AddLabeledControl(grid, "休息时长", _standingCombo, 2);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        var cancel = new Button
        {
            Content = "取消",
            Width = 86,
            Margin = new Thickness(0, 0, 10, 0),
            IsCancel = true
        };
        var save = new Button
        {
            Content = "保存设置",
            Width = 100,
            IsDefault = true
        };
        save.Click += (_, _) =>
        {
            if (_workCombo.SelectedItem is not int workMinutes ||
                _standingCombo.SelectedItem is not int standingMinutes)
            {
                return;
            }

            Result = ReminderConfiguration.Create(
                TimeSpan.FromMinutes(workMinutes),
                TimeSpan.FromMinutes(standingMinutes));
            DialogResult = true;
        };
        buttons.Children.Add(cancel);
        buttons.Children.Add(save);
        Grid.SetRow(buttons, 4);
        Grid.SetColumnSpan(buttons, 2);
        grid.Children.Add(buttons);

        Content = grid;
    }

    public ReminderConfiguration? Result { get; private set; }

    private static void Populate(
        ComboBox combo,
        IEnumerable<int> options,
        TimeSpan selectedDuration)
    {
        foreach (var minutes in options)
        {
            combo.Items.Add(minutes);
        }

        combo.SelectedItem = (int)Math.Round(selectedDuration.TotalMinutes);
        combo.MinWidth = 150;
    }

    private static void AddLabeledControl(
        Grid grid,
        string label,
        Control control,
        int row)
    {
        var text = new TextBlock
        {
            Text = label,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 8, 20, 8)
        };
        control.Margin = new Thickness(0, 8, 0, 8);
        Grid.SetRow(text, row);
        Grid.SetColumn(text, 0);
        Grid.SetRow(control, row);
        Grid.SetColumn(control, 1);
        grid.Children.Add(text);
        grid.Children.Add(control);
    }
}
