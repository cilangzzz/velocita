/// A single download category.
///
/// Carries the IDM-style fields:
///   - `id`             stable identifier (lowercase, kebab-case)
///   - `name`           display name shown in the sidebar
///   - `defaultSaveDir` where files matched by this category land by default
///   - `extensions`     lowercased file extensions (`.mp4`, `.mkv`, …)
///   - `iconName`       lucide icon name (resolved to IconData by the UI)
///   - `isDefault`      true for the seed categories shipped with the app
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.defaultSaveDir,
    required this.extensions,
    this.iconName,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String defaultSaveDir;
  final List<String> extensions;
  final String? iconName;
  final bool isDefault;

  Category copyWith({
    String? name,
    String? defaultSaveDir,
    List<String>? extensions,
    String? iconName,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      defaultSaveDir: defaultSaveDir ?? this.defaultSaveDir,
      extensions: extensions ?? this.extensions,
      iconName: iconName ?? this.iconName,
      isDefault: isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'defaultSaveDir': defaultSaveDir,
        'extensions': extensions,
        'iconName': iconName,
        'isDefault': isDefault,
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        defaultSaveDir: json['defaultSaveDir'] as String,
        extensions: (json['extensions'] as List).map((e) => e as String).toList(),
        iconName: json['iconName'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  /// The default seed set — IDM-style.
  static List<Category> defaults(String downloadDir) => [
        Category(
          id: 'video',
          name: 'Videos',
          defaultSaveDir: '$downloadDir\\Videos',
          extensions: ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.wmv', '.m4v'],
          iconName: 'movie',
          isDefault: true,
        ),
        Category(
          id: 'music',
          name: 'Music',
          defaultSaveDir: '$downloadDir\\Music',
          extensions: ['.mp3', '.flac', '.wav', '.aac', '.ogg', '.m4a', '.opus'],
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
          iconName: 'package',
          isDefault: true,
        ),
        Category(
          id: 'image',
          name: 'Images',
          defaultSaveDir: '$downloadDir\\Images',
          extensions: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp'],
          iconName: 'image',
          isDefault: true,
        ),
      ];
}
