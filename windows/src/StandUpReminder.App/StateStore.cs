using System.Text.Json;
using System.Text.Json.Serialization;
using StandUpReminder.Core;

namespace StandUpReminder.App;

internal sealed class StateStore
{
    private sealed record SettingsDocument(
        int Version,
        double WorkDurationMinutes,
        double StandingDurationMinutes);

    private sealed record StateDocument(
        int Version,
        ReminderSnapshot Snapshot,
        string CompletedDate,
        int CompletedCount);

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly string _directory;
    private readonly string _settingsPath;
    private readonly string _statePath;
    private StateDocument? _state;

    public StateStore(string? baseDirectory = null)
    {
        _directory = baseDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "StandUpReminder");
        _settingsPath = Path.Combine(_directory, "settings.json");
        _statePath = Path.Combine(_directory, "state.json");
    }

    public ReminderConfiguration LoadConfiguration()
    {
        var document = Read<SettingsDocument>(_settingsPath);
        if (document is null ||
            document.Version != 1 ||
            document.WorkDurationMinutes is < 5 or > 240 ||
            document.StandingDurationMinutes is < 1 or > 60)
        {
            return ReminderConfiguration.Standard;
        }

        return ReminderConfiguration.Create(
            TimeSpan.FromMinutes(document.WorkDurationMinutes),
            TimeSpan.FromMinutes(document.StandingDurationMinutes));
    }

    public void SaveConfiguration(ReminderConfiguration configuration)
    {
        WriteAtomically(
            _settingsPath,
            new SettingsDocument(
                1,
                configuration.WorkDuration.TotalMinutes,
                configuration.StandingDuration.TotalMinutes));
    }

    public ReminderSnapshot? LoadSnapshot()
    {
        _state = Read<StateDocument>(_statePath);
        return _state?.Version == 1 ? _state.Snapshot : null;
    }

    public void SaveSnapshot(ReminderSnapshot snapshot)
    {
        var today = DateOnly.FromDateTime(DateTime.Now).ToString("O");
        var current = NormalizedState(snapshot, today);
        _state = current;
        WriteAtomically(_statePath, current);
    }

    public int CompletedCount(ReminderSnapshot snapshot)
    {
        var today = DateOnly.FromDateTime(DateTime.Now).ToString("O");
        _state = NormalizedState(snapshot, today);
        return _state.CompletedCount;
    }

    public int RecordCompletion(ReminderSnapshot snapshot)
    {
        var today = DateOnly.FromDateTime(DateTime.Now).ToString("O");
        var current = NormalizedState(snapshot, today);
        current = current with { CompletedCount = current.CompletedCount + 1 };
        _state = current;
        WriteAtomically(_statePath, current);
        return current.CompletedCount;
    }

    private StateDocument NormalizedState(
        ReminderSnapshot snapshot,
        string today)
    {
        if (_state is null || _state.Version != 1 || _state.CompletedDate != today)
        {
            return new StateDocument(1, snapshot, today, 0);
        }

        return _state with { Snapshot = snapshot };
    }

    private static T? Read<T>(string path)
    {
        try
        {
            return File.Exists(path)
                ? JsonSerializer.Deserialize<T>(File.ReadAllText(path), JsonOptions)
                : default;
        }
        catch (JsonException)
        {
            return default;
        }
        catch (IOException)
        {
            return default;
        }
        catch (UnauthorizedAccessException)
        {
            return default;
        }
    }

    private void WriteAtomically<T>(string path, T value)
    {
        try
        {
            Directory.CreateDirectory(_directory);
            var temporaryPath = path + ".tmp";
            File.WriteAllText(
                temporaryPath,
                JsonSerializer.Serialize(value, JsonOptions));
            File.Move(temporaryPath, path, overwrite: true);
        }
        catch (IOException)
        {
            // 持久化失败不应终止提醒进程，下一次周期保存会重试。
        }
        catch (UnauthorizedAccessException)
        {
            // 目录权限异常时继续维持本次运行中的内存状态。
        }
    }
}
