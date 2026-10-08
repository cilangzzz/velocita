import '../../../features/categories/categories.dart';
import '../domain/download_task.dart';
import 'task_list_provider.dart' show DownloadFilter;

/// Pure filtering helpers for the visible task list.
///
/// The downloads table and the batch-operations toolbar both need the
/// same answer to "which gids are currently visible?" so they don't
/// drift; these functions are the single source of truth.

List<TaskSummary> applyDownloadFilter(
  List<TaskSummary> source,
  DownloadFilter f,
) {
  switch (f) {
    case DownloadFilter.all:
      return source;
    case DownloadFilter.active:
      return source.where((t) => t.isActive).toList();
    case DownloadFilter.paused:
      return source.where((t) => t.isPaused).toList();
    case DownloadFilter.completed:
      return source.where((t) => t.isComplete).toList();
    case DownloadFilter.error:
      return source.where((t) => t.isError).toList();
  }
}

List<TaskSummary> applyCategoryFilter(
  List<TaskSummary> source,
  String? categoryId,
  List<Category> categories,
) {
  if (categoryId == null) return source;
  if (categoryId == '__none__') {
    return source
        .where((t) => !dirMatchesAnyCategory(categories, t.dir))
        .toList();
  }
  if (categoryById(categories, categoryId) == null) return source;
  return source
      .where((t) => categoryIncludesDir(categories, categoryId, t.dir))
      .toList();
}

/// The gids visible after applying the status + category filters.
/// (Sort doesn't change which gids are visible, just their order.)
Set<String> visibleGids(
  List<TaskSummary> source,
  DownloadFilter filter,
  String? categoryId,
  List<Category> categories,
) {
  var list = applyDownloadFilter(source, filter);
  list = applyCategoryFilter(list, categoryId, categories);
  return list.map((t) => t.gid).toSet();
}
