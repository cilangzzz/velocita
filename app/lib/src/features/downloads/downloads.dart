/// Public surface for the downloads feature.
///
/// Per `docs/rule/flutter_rule/01-architecture.md` §"Feature module
/// contract", every feature folder MUST contain a barrel file that
/// re-exports the public surface only. Internal files (data/, domain/)
/// stay private.
library;

export 'domain/download_task.dart' show TaskSummary, DownloadStatus, TaskFilter, taskFromAria2;
export 'data/downloads_repository.dart' show DownloadsRepository, downloadsRepositoryProvider;
export 'presentation/task_list_provider.dart'
    show
        taskListProvider,
        DownloadFilter,
        taskFilterProvider;
export 'presentation/downloads_screen.dart'
    show
        DownloadsScreen,
        sortStateProvider,
        SortColumn;
export 'presentation/selected_tasks_provider.dart' show selectedTaskGidsProvider;
export 'presentation/add_task_dialog.dart' show AddTaskDialog, SubmitResult, SubmitKind;
