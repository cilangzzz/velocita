import 'package:flutter/material.dart';

import '../data/category_icon_store.dart';

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
            // HLS / DASH playlists — a `.m3u8` URL should route into
            // Videos, not the catch-all.
            '.m3u8',
            '.m3u',
            '.mpd',
            '.ts',
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
/// Only handles Material icon keys. For user-uploaded images (which
/// use the `image:<id>` sentinel), use [categoryIconWidget] instead.
IconData categoryIcon(String? key) {
  // Custom images have no IconData equivalent; return a neutral
  // fallback so callers that want the legacy `IconData` API still
  // compile. The renderer should branch on [CategoryIconStore.isCustom]
  // first and use [categoryIconWidget] for the actual drawing.
  if (CategoryIconStore.isCustom(key)) {
    return Icons.image_outlined;
  }
  return _kIconDataMap[key] ?? Icons.folder_outlined;
}

/// Render the right widget for [Category.iconName]: an
/// [Image.file] for a user-uploaded image (sentinel `image:<id>`),
/// or an [Icon] for a Material icon key.
///
/// Sized to fit a 16 px sidebar row by default. Returns a folder
/// icon as the ultimate fallback.
Widget categoryIconWidget(String? key, {double size = 16, Color? color}) {
  if (CategoryIconStore.isCustom(key)) {
    final file = CategoryIconStore.resolve(key);
    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // The source file might be larger than we need; let it
        // scale down smoothly.
        filterQuality: FilterQuality.medium,
        // Visible if the file was deleted out from under us.
        errorBuilder: (_, __, ___) =>
            Icon(Icons.broken_image_outlined, size: size, color: color),
      );
    }
    return Icon(Icons.image_outlined, size: size, color: color);
  }
  return Icon(categoryIcon(key), size: size, color: color);
}

/// All Material icon keys the category editor lets the user pick
/// from, in display order. Grouped semantically; the icon picker
/// flattens this list for the search-as-you-type field.
const List<String> kMaterialIconNames = [
  // file / folder
  'folder', 'folder_open', 'folder_zip', 'folder_shared', 'folder_special',
  'topic', 'file_open', 'insert_drive_file', 'draft', 'attachment',
  'cloud_queue', 'work', 'work_outline', 'category',
  // images / media
  'image', 'image_outlined', 'photo', 'photo_library', 'photo_camera',
  'camera', 'camera_alt', 'image_search', 'broken_image', 'wallpaper',
  'palette', 'brush', 'color_lens', 'gradient',
  // video
  'movie', 'movie_outlined', 'video_library', 'videocam', 'movie_creation',
  'live_tv', 'tv', 'smart_display', 'play_circle', 'slow_motion_video',
  // music / audio
  'music_note', 'music_video', 'library_music', 'headphones', 'mic',
  'radio', 'podcasts', 'album', 'graphic_eq', 'queue_music',
  // documents
  'description', 'article', 'picture_as_pdf', 'text_snippet', 'note',
  'sticky_note_2', 'book', 'menu_book', 'auto_stories', 'import_contacts',
  'history_edu', 'receipt', 'request_quote', 'fact_check', 'rule',
  'contact_page', 'business_center', 'assignment', 'assignment_ind',
  'task', 'task_alt', 'checklist', 'checklist_rtl',
  // spreadsheets / presentations
  'table_chart', 'table_view', 'grid_on', 'view_module', 'data_table',
  'slideshow', 'co_present', 'present_to_all', 'cast_for_education',
  // archives
  'archive', 'inventory', 'inventory_2', 'unarchive', 'warehouse',
  // code / dev
  'code', 'terminal', 'developer_mode', 'data_object', 'schema', 'memory',
  'build', 'construction', 'engineering', 'science', 'integration_instructions',
  'api', 'webhook', 'deployed_code', 'ad_units', 'html', 'css',
  'web', 'http', 'dns', 'router', 'lan', 'wifi', 'vpn_key', 'lock', 'shield',
  // programs / system
  'apps', 'app', 'computer', 'desktop_windows', 'laptop', 'laptop_chromebook',
  'laptop_mac', 'smartphone', 'tablet', 'watch', 'keyboard', 'mouse',
  'headset', 'videogame_asset', 'sports_esports', 'extension', 'widget',
  'dashboard', 'web_asset', 'important_devices', 'browser_updated',
  'install_desktop', 'install_mobile', 'device_unknown',
  // cloud / network
  'cloud', 'cloud_upload', 'cloud_download', 'cloud_sync', 'cloud_done',
  'cloud_circle', 'cloud_off', 'public', 'language', 'link', 'share',
  'group', 'groups', 'person', 'account_circle', 'account_box', 'contacts',
  'forum', 'chat',
  // actions
  'download', 'download_done', 'upload', 'save', 'save_alt', 'edit',
  'delete', 'add', 'remove', 'close', 'search', 'home', 'refresh', 'sync',
  // status / bookmarks
  'check', 'check_circle', 'error', 'error_outline', 'warning',
  'warning_amber', 'info', 'star', 'star_border', 'favorite', 'favorite_border',
  'flag', 'bookmark', 'bookmark_border', 'label', 'label_important',
  // misc
  'lightbulb', 'schedule', 'event', 'place', 'location_on', 'map', 'explore',
  'navigation', 'directions', 'pin_drop', 'where_to_vote', 'cake',
  'celebration', 'card_giftcard', 'redeem', 'school', 'pets', 'spa', 'park',
  'forest', 'eco', 'recycling', 'compost', 'design_services', 'architecture',
  'handyman', 'plumbing', 'electrical_services', 'format_paint', 'opacity',
  // generic / fallback
  'generic', 'other', 'help', 'help_outline', 'pending',
];

/// Map of icon key → [IconData], used by [categoryIcon] and the
/// icon picker. Lazily computed from [kMaterialIconNames] using
/// Flutter's `Icons.<name>` constants; an unknown name falls back
/// to a folder icon.
final Map<String, IconData> _kIconDataMap = _buildIconDataMap();

Map<String, IconData> _buildIconDataMap() {
  // We can't iterate `Icons.<name>` at runtime because the
  // constants aren't a Map. Instead we hard-link the most-used
  // keys so `Icons.video_file` etc. resolve correctly.
  const m = <String, IconData>{
    'video': Icons.movie_outlined,
    'movie': Icons.movie_outlined, // legacy alias
    'music': Icons.music_note_outlined,
    'document': Icons.description_outlined,
    'archive': Icons.archive_outlined,
    'program': Icons.inventory_2_outlined,
    'package': Icons.inventory_2_outlined, // legacy alias
    'image': Icons.image_outlined,
    'image_outlined': Icons.image_outlined,
    'folder': Icons.folder_outlined,
    'folder_open': Icons.folder_open,
    'folder_zip': Icons.folder_zip_outlined,
    'folder_shared': Icons.folder_shared,
    'folder_special': Icons.folder_special_outlined,
    'topic': Icons.topic_outlined,
    'file_open': Icons.file_open_outlined,
    'insert_drive_file': Icons.insert_drive_file_outlined,
    'draft': Icons.drafts_outlined,
    'attachment': Icons.attachment_outlined,
    'photo': Icons.photo_outlined,
    'photo_library': Icons.photo_library_outlined,
    'photo_camera': Icons.photo_camera_outlined,
    'camera': Icons.camera_outlined,
    'camera_alt': Icons.camera_alt_outlined,
    'image_search': Icons.image_search_outlined,
    'broken_image': Icons.broken_image_outlined,
    'wallpaper': Icons.wallpaper_outlined,
    'palette': Icons.palette_outlined,
    'brush': Icons.brush_outlined,
    'color_lens': Icons.color_lens_outlined,
    'gradient': Icons.gradient_outlined,
    'movie_outlined': Icons.movie_outlined,
    'video_library': Icons.video_library_outlined,
    'videocam': Icons.videocam_outlined,
    'movie_creation': Icons.movie_creation_outlined,
    'live_tv': Icons.live_tv_outlined,
    'tv': Icons.tv_outlined,
    'smart_display': Icons.smart_display_outlined,
    'play_circle': Icons.play_circle_outline,
    'slow_motion_video': Icons.slow_motion_video_outlined,
    'music_note': Icons.music_note_outlined,
    'music_video': Icons.music_video_outlined,
    'library_music': Icons.library_music_outlined,
    'headphones': Icons.headphones_outlined,
    'mic': Icons.mic_outlined,
    'radio': Icons.radio_outlined,
    'podcasts': Icons.podcasts_outlined,
    'album': Icons.album_outlined,
    'graphic_eq': Icons.graphic_eq_outlined,
    'queue_music': Icons.queue_music_outlined,
    'description': Icons.description_outlined,
    'article': Icons.article_outlined,
    'picture_as_pdf': Icons.picture_as_pdf_outlined,
    'text_snippet': Icons.text_snippet_outlined,
    'note': Icons.note_outlined,
    'sticky_note_2': Icons.sticky_note_2_outlined,
    'book': Icons.menu_book_outlined,
    'menu_book': Icons.menu_book_outlined,
    'auto_stories': Icons.auto_stories_outlined,
    'import_contacts': Icons.import_contacts_outlined,
    'history_edu': Icons.history_edu_outlined,
    'receipt': Icons.receipt_outlined,
    'request_quote': Icons.request_quote_outlined,
    'fact_check': Icons.fact_check_outlined,
    'rule': Icons.rule_outlined,
    'contact_page': Icons.contact_page_outlined,
    'business_center': Icons.business_center_outlined,
    'assignment': Icons.assignment_outlined,
    'assignment_ind': Icons.assignment_ind_outlined,
    'task': Icons.task_outlined,
    'task_alt': Icons.task_alt_outlined,
    'checklist': Icons.checklist_outlined,
    'checklist_rtl': Icons.checklist_rtl_outlined,
    'table_chart': Icons.table_chart_outlined,
    'table_view': Icons.table_view_outlined,
    'grid_on': Icons.grid_on_outlined,
    'view_module': Icons.view_module_outlined,
    'data_table': Icons.table_chart_outlined,
    'slideshow': Icons.slideshow_outlined,
    'co_present': Icons.co_present_outlined,
    'present_to_all': Icons.present_to_all_outlined,
    'cast_for_education': Icons.cast_for_education_outlined,
    'inventory': Icons.inventory_outlined,
    'inventory_2': Icons.inventory_2_outlined,
    'unarchive': Icons.unarchive_outlined,
    'warehouse': Icons.warehouse_outlined,
    'terminal': Icons.terminal_outlined,
    'developer_mode': Icons.developer_mode_outlined,
    'data_object': Icons.data_object_outlined,
    'schema': Icons.schema_outlined,
    'memory': Icons.memory_outlined,
    'build': Icons.build_outlined,
    'construction': Icons.construction_outlined,
    'engineering': Icons.engineering_outlined,
    'science': Icons.science_outlined,
    'integration_instructions': Icons.integration_instructions_outlined,
    'api': Icons.api_outlined,
    'webhook': Icons.webhook_outlined,
    'deployed_code': Icons.code_outlined,
    'ad_units': Icons.ad_units_outlined,
    'html': Icons.html_outlined,
    'css': Icons.css_outlined,
    'web': Icons.web_outlined,
    'http': Icons.http_outlined,
    'dns': Icons.dns_outlined,
    'router': Icons.router_outlined,
    'lan': Icons.lan_outlined,
    'wifi': Icons.wifi_outlined,
    'vpn_key': Icons.vpn_key_outlined,
    'lock': Icons.lock_outlined,
    'shield': Icons.shield_outlined,
    'apps': Icons.apps_outlined,
    'app': Icons.app_shortcut_outlined,
    'computer': Icons.computer_outlined,
    'desktop_windows': Icons.desktop_windows_outlined,
    'laptop': Icons.laptop_outlined,
    'laptop_chromebook': Icons.laptop_chromebook_outlined,
    'laptop_mac': Icons.laptop_mac_outlined,
    'smartphone': Icons.smartphone_outlined,
    'tablet': Icons.tablet_outlined,
    'watch': Icons.watch_outlined,
    'keyboard': Icons.keyboard_outlined,
    'mouse': Icons.mouse_outlined,
    'headset': Icons.headset_outlined,
    'videogame_asset': Icons.videogame_asset_outlined,
    'sports_esports': Icons.sports_esports_outlined,
    'extension': Icons.extension_outlined,
    'widget': Icons.widgets_outlined,
    'dashboard': Icons.dashboard_outlined,
    'web_asset': Icons.web_asset_outlined,
    'important_devices': Icons.important_devices_outlined,
    'browser_updated': Icons.browser_updated_outlined,
    'install_desktop': Icons.install_desktop_outlined,
    'install_mobile': Icons.install_mobile_outlined,
    'device_unknown': Icons.device_unknown_outlined,
    'cloud': Icons.cloud_outlined,
    'cloud_upload': Icons.cloud_upload_outlined,
    'cloud_download': Icons.cloud_download_outlined,
    'cloud_sync': Icons.cloud_sync_outlined,
    'cloud_done': Icons.cloud_done_outlined,
    'cloud_circle': Icons.cloud_circle_outlined,
    'cloud_off': Icons.cloud_off_outlined,
    'cloud_queue': Icons.cloud_queue_outlined,
    'public': Icons.public_outlined,
    'language': Icons.language_outlined,
    'link': Icons.link_outlined,
    'share': Icons.share_outlined,
    'group': Icons.group_outlined,
    'groups': Icons.groups_outlined,
    'person': Icons.person_outlined,
    'account_circle': Icons.account_circle_outlined,
    'account_box': Icons.account_box_outlined,
    'contacts': Icons.contacts_outlined,
    'forum': Icons.forum_outlined,
    'chat': Icons.chat_outlined,
    'download': Icons.download_outlined,
    'download_done': Icons.download_done_outlined,
    'upload': Icons.upload_outlined,
    'save': Icons.save_outlined,
    'save_alt': Icons.save_alt_outlined,
    'edit': Icons.edit_outlined,
    'delete': Icons.delete_outline,
    'add': Icons.add_outlined,
    'remove': Icons.remove_outlined,
    'close': Icons.close_outlined,
    'search': Icons.search_outlined,
    'home': Icons.home_outlined,
    'refresh': Icons.refresh_outlined,
    'sync': Icons.sync_outlined,
    'check': Icons.check_outlined,
    'check_circle': Icons.check_circle_outline,
    'error': Icons.error_outline,
    'error_outline': Icons.error_outline,
    'warning': Icons.warning_amber_outlined,
    'warning_amber': Icons.warning_amber_outlined,
    'info': Icons.info_outline,
    'star': Icons.star_outline,
    'star_border': Icons.star_outline,
    'favorite': Icons.favorite_outline,
    'favorite_border': Icons.favorite_outline,
    'flag': Icons.flag_outlined,
    'bookmark': Icons.bookmark_outline,
    'bookmark_border': Icons.bookmark_outline,
    'label': Icons.label_outline,
    'label_important': Icons.label_important_outline,
    'lightbulb': Icons.lightbulb_outline,
    'schedule': Icons.schedule_outlined,
    'event': Icons.event_outlined,
    'place': Icons.place_outlined,
    'location_on': Icons.location_on_outlined,
    'map': Icons.map_outlined,
    'explore': Icons.explore_outlined,
    'navigation': Icons.navigation_outlined,
    'directions': Icons.directions_outlined,
    'pin_drop': Icons.pin_drop_outlined,
    'where_to_vote': Icons.where_to_vote_outlined,
    'cake': Icons.cake_outlined,
    'celebration': Icons.celebration_outlined,
    'card_giftcard': Icons.card_giftcard_outlined,
    'redeem': Icons.redeem_outlined,
    'school': Icons.school_outlined,
    'pets': Icons.pets_outlined,
    'spa': Icons.spa_outlined,
    'park': Icons.park_outlined,
    'forest': Icons.forest_outlined,
    'eco': Icons.eco_outlined,
    'recycling': Icons.recycling_outlined,
    'compost': Icons.compost_outlined,
    'design_services': Icons.design_services_outlined,
    'architecture': Icons.architecture_outlined,
    'handyman': Icons.handyman_outlined,
    'plumbing': Icons.plumbing_outlined,
    'electrical_services': Icons.electrical_services_outlined,
    'format_paint': Icons.format_paint_outlined,
    'opacity': Icons.opacity_outlined,
    'work': Icons.work_outline,
    'work_outline': Icons.work_outline,
    'category': Icons.category_outlined,
    'generic': Icons.insert_drive_file_outlined,
    'other': Icons.folder_off_outlined,
    'help': Icons.help_outline,
    'help_outline': Icons.help_outline,
    'pending': Icons.pending_outlined,
  };
  return m;
}
