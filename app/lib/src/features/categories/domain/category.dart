import 'package:flutter/material.dart';

/// A single download category.
///
/// Carries the IDM-style fields plus the user-managed ones the tree
/// sidebar needs:
///   - `id`             stable identifier (lowercase, kebab-case)
///   - `name`           display name shown in the sidebar
///   - `parentId`       id of the parent category, or `null` for a root
///   - `defaultSaveDir` where files matched by this category land by default
///   - `extensions`     lowercased file extensions (`.mp4`, `.mkv`, …)
///   - `sites`          lowercased hostnames whose URLs default-route here
///   - `iconName`       key into [categoryIcons] (resolved to IconData)
///   - `isDefault`      true for the seed categories shipped with the app
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.defaultSaveDir,
    required this.extensions,
    this.parentId,
    this.sites = const [],
    this.iconName,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String? parentId;
  final String defaultSaveDir;
  final List<String> extensions;
  final List<String> sites;
  final String? iconName;
  final bool isDefault;

  /// Sentinel object for [copyWith] to distinguish "not passed" from
  /// "passed `null`" for the nullable fields. Without this you cannot
  /// clear a previously-set parentId or iconName.
  static const Object _unset = Object();

  Category copyWith({
    String? name,
    String? defaultSaveDir,
    List<String>? extensions,
    List<String>? sites,
    Object? parentId = _unset,
    Object? iconName = _unset,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      defaultSaveDir: defaultSaveDir ?? this.defaultSaveDir,
      extensions: extensions ?? this.extensions,
      sites: sites ?? this.sites,
      parentId: identical(parentId, _unset)
          ? this.parentId
          : parentId as String?,
      iconName: identical(iconName, _unset)
          ? this.iconName
          : iconName as String?,
      isDefault: isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'defaultSaveDir': defaultSaveDir,
        'extensions': extensions,
        'sites': sites,
        'iconName': iconName,
        'isDefault': isDefault,
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parentId'] as String?,
        defaultSaveDir: json['defaultSaveDir'] as String,
        extensions: (json['extensions'] as List)
            .map((e) => e as String)
            .toList(),
        sites: (json['sites'] as List?)?.cast<String>() ?? const [],
        iconName: json['iconName'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  /// The default seed set — 6 extension-driven buckets plus a catch-all
  /// `other` category. All are `isDefault: true` (and therefore
  /// undeletable). Save-dirs are nested under [downloadDir].
  static List<Category> defaults(String downloadDir) => [
        Category(
          id: 'video',
          name: 'Videos',
          defaultSaveDir: '$downloadDir\\Videos',
          extensions: [
            '.mp4',
            '.mkv',
            '.avi',
            '.mov',
            '.webm',
            '.flv',
            '.wmv',
            '.m4v',
          ],
          iconName: 'video',
          isDefault: true,
        ),
        Category(
          id: 'music',
          name: 'Music',
          defaultSaveDir: '$downloadDir\\Music',
          extensions: [
            '.mp3',
            '.flac',
            '.wav',
            '.aac',
            '.ogg',
            '.m4a',
            '.opus',
          ],
          iconName: 'music',
          isDefault: true,
        ),
        Category(
          id: 'document',
          name: 'Documents',
          defaultSaveDir: '$downloadDir\\Documents',
          extensions: ['.pdf', '.doc', '.docx', '.txt', '.md', '.rtf', '.odt'],
          iconName: 'document',
          isDefault: true,
        ),
        Category(
          id: 'archive',
          name: 'Archives',
          defaultSaveDir: '$downloadDir\\Archives',
          extensions: ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz'],
          iconName: 'archive',
          isDefault: true,
        ),
        Category(
          id: 'program',
          name: 'Programs',
          defaultSaveDir: '$downloadDir\\Programs',
          extensions: ['.exe', '.msi', '.dmg', '.deb', '.rpm', '.appimage'],
          iconName: 'program',
          isDefault: true,
        ),
        Category(
          id: 'image',
          name: 'Images',
          defaultSaveDir: '$downloadDir\\Images',
          extensions: [
            '.jpg',
            '.jpeg',
            '.png',
            '.gif',
            '.webp',
            '.svg',
            '.bmp',
          ],
          iconName: 'image',
          isDefault: true,
        ),
        // Catch-all. Empty extensions means it never wins the
        // extension-matching race; the add-task dialog falls back to
        // it when nothing else fires.
        Category(
          id: 'other',
          name: 'Other',
          defaultSaveDir: '$downloadDir\\Other',
          extensions: const [],
          iconName: 'other',
          isDefault: true,
        ),
      ];
}

/// Resolve [Category.iconName] (or `null`) to a Material [IconData].
///
/// New code should use one of the canonical keys below; legacy
/// `categories.json` files written before the tree feature shipped
/// stored `movie` / `package` — those aliases are kept so old data
/// keeps rendering.
final Map<String, IconData> categoryIcons = {
  'video': Icons.movie_outlined,
  'movie': Icons.movie_outlined, // legacy alias
  'music': Icons.music_note_outlined,
  'document': Icons.description_outlined,
  'archive': Icons.archive_outlined,
  'program': Icons.inventory_2_outlined,
  'package': Icons.inventory_2_outlined, // legacy alias
  'image': Icons.image_outlined,
  'other': Icons.folder_off_outlined,
  'folder': Icons.folder_outlined,
  'book': Icons.menu_book_outlined,
  'game': Icons.sports_esports_outlined,
  'code': Icons.code,
  'iso': Icons.disc_full_outlined,
  'cloud': Icons.cloud_outlined,
  'photo': Icons.photo_library_outlined,
  'text': Icons.notes_outlined,
  'font': Icons.text_fields,
  'design': Icons.palette_outlined,
  'spreadsheet': Icons.table_chart_outlined,
  'presentation': Icons.slideshow_outlined,
  'pdf': Icons.picture_as_pdf_outlined,
  'app': Icons.apps_outlined,
  'generic': Icons.insert_drive_file_outlined,
};

/// Lookup helper. Unknown keys (and `null`) fall back to a folder icon.
IconData categoryIcon(String? key) =>
    categoryIcons[key] ?? Icons.folder_outlined;
