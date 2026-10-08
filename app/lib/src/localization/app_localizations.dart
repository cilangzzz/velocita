import 'dart:async';

import 'package:flutter/material.dart';

/// Minimal i18n facade backed by a static catalog.
///
/// M3 uses this while the full `intl` + arb pipeline lands in M4 alongside
/// the actual translated catalogs.
class AppLocalizations {
  AppLocalizations._(this.locale);

  final Locale locale;

  static const supported = ['en', 'zh-CN'];
  static const fallback = Locale('en');

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return loc ?? AppLocalizations._(fallback);
  }

  static Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations._(locale);
  }

  // ── Catalog ──────────────────────────────────────────────
  String get appTitle => _t(_catalog['appTitle']!);
  String get downloadsTab => _t(_catalog['downloadsTab']!);
  String get addUrl => _t(_catalog['addUrl']!);
  String get refresh => _t(_catalog['refresh']!);
  String get cancel => _t(_catalog['cancel']!);
  String get download => _t(_catalog['download']!);
  String get all => _t(_catalog['all']!);
  String get active => _t(_catalog['active']!);
  String get paused => _t(_catalog['paused']!);
  String get completed => _t(_catalog['completed']!);
  String get error => _t(_catalog['error']!);
  String get categories => _t(_catalog['categories']!);
  String get allDownloads => _t(_catalog['allDownloads']!);
  String get uncategorized => _t(_catalog['uncategorized']!);
  String get documents => _t(_catalog['documents']!);
  String get programs => _t(_catalog['programs']!);
  String get images => _t(_catalog['images']!);
  String get manageCategories => _t(_catalog['manageCategories']!);
  String get movies => _t(_catalog['movies']!);
  String get music => _t(_catalog['music']!);
  String get archives => _t(_catalog['archives']!);
  String get engineConnected => _t(_catalog['engineConnected']!);
  String get engineDisconnected => _t(_catalog['engineDisconnected']!);
  String get noDownloads => _t(_catalog['noDownloads']!);
  String get noActive => _t(_catalog['noActive']!);
  String get noPaused => _t(_catalog['noPaused']!);
  String get noCompleted => _t(_catalog['noCompleted']!);
  String get noError => _t(_catalog['noError']!);
  String get addDownload => _t(_catalog['addDownload']!);
  String get addDownloadTask => _t(_catalog['addDownloadTask']!);
  String get urlHint => _t(_catalog['urlHint']!);
  String get magnetHint => _t(_catalog['magnetHint']!);
  String get urlInvalid => _t(_catalog['urlInvalid']!);
  String get magnetInvalid => _t(_catalog['magnetInvalid']!);
  String get magnetMissingBtih => _t(_catalog['magnetMissingBtih']!);
  String get urlRequired => _t(_catalog['urlRequired']!);
  String get chooseTorrent => _t(_catalog['chooseTorrent']!);
  String get saveTo => _t(_catalog['saveTo']!);
  String get saveToHint => _t(_catalog['saveToHint']!);
  String get customDirectory => _t(_catalog['customDirectory']!);
  String get tabUrl => _t(_catalog['tabUrl']!);
  String get tabMagnet => _t(_catalog['tabMagnet']!);
  String get tabTorrent => _t(_catalog['tabTorrent']!);
  String get magnetLabel => _t(_catalog['magnetLabel']!);
  String get settings => _t(_catalog['settings']!);
  String get scheduler => _t(_catalog['scheduler']!);
  String get plugins => _t(_catalog['plugins']!);
  String get general => _t(_catalog['general']!);
  String get downloads => _t(_catalog['downloads']!);
  String get connection => _t(_catalog['connection']!);
  String get schedulerOffPeak => _t(_catalog['schedulerOffPeak']!);
  String get schedulerPeak => _t(_catalog['schedulerPeak']!);
  String get schedulerAdd => _t(_catalog['schedulerAdd']!);
  String get pluginEnable => _t(_catalog['pluginEnable']!);
  String get pluginDisable => _t(_catalog['pluginDisable']!);
  String get pluginInstall => _t(_catalog['pluginInstall']!);
  String get settingsTitle => _t(_catalog['settingsTitle']!);
  String get themeDark => _t(_catalog['themeDark']!);
  String get themeLight => _t(_catalog['themeLight']!);
  String get themeSystem => _t(_catalog['themeSystem']!);
  String get comingSoon => _t(_catalog['comingSoon']!);
  String get settingsTheme => _t(_catalog['settingsTheme']!);
  String get settingsLanguage => _t(_catalog['settingsLanguage']!);
  String get langEnglish => _t(_catalog['langEnglish']!);
  String get langChinese => _t(_catalog['langChinese']!);
  String get settingSaveDir => _t(_catalog['settingSaveDir']!);
  String get settingMaxConcurrent => _t(_catalog['settingMaxConcurrent']!);
  String get settingSpeedLimits => _t(_catalog['settingSpeedLimits']!);
  String get settingProxy => _t(_catalog['settingProxy']!);
  String get settingNatUpnp => _t(_catalog['settingNatUpnp']!);

  String _t(String key) {
    final tag = locale.countryCode != null
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;
    final langMap = _strings[tag];
    final value = langMap?[key] ?? _strings['en']![key] ?? key;
    return value;
  }
}

// ── Catalog ───────────────────────────────────────────────

const Map<String, Map<String, String>> _strings = {
  'en': {
    'appTitle': 'Velocita',
    'downloadsTab': 'Downloads',
    'addUrl': 'Add URL',
    'refresh': 'Refresh',
    'cancel': 'Cancel',
    'download': 'Download',
    'all': 'All',
    'active': 'Active',
    'paused': 'Paused',
    'completed': 'Completed',
    'error': 'Error',
    'categories': 'CATEGORIES',
    'allDownloads': 'All Downloads',
    'uncategorized': 'Uncategorized',
    'movies': 'Movies',
    'music': 'Music',
    'archives': 'Archives',
    'documents': 'Documents',
    'programs': 'Programs',
    'images': 'Images',
    'manageCategories': 'Manage categories',
    'engineConnected': 'Engine: Connected',
    'engineDisconnected': 'Engine: Disconnected',
    'noDownloads': 'No downloads yet — click "Add URL".',
    'noActive': 'No active downloads.',
    'noPaused': 'No paused downloads.',
    'noCompleted': 'No completed downloads.',
    'noError': 'No failed downloads.',
    'addDownload': 'Add Download',
    'addDownloadTask': 'Add Download Task',
    'urlHint': 'https://example.com/file.zip',
    'magnetHint': 'magnet:?xt=urn:btih:...',
    'urlInvalid': 'Must be an http(s) URL',
    'magnetInvalid': 'Must start with magnet:?',
    'magnetMissingBtih': 'Missing urn:btih: exact-topic',
    'urlRequired': 'URL is required',
    'chooseTorrent': 'Choose .torrent file',
    'saveTo': 'Save to',
    'saveToHint': '/path/to/save',
    'customDirectory': 'Custom…',
    'tabUrl': 'URL',
    'tabMagnet': 'Magnet',
    'tabTorrent': 'Torrent',
    'magnetLabel': 'Magnet URI',
    'settings': 'Settings',
    'scheduler': 'Scheduler',
    'plugins': 'Plugins',
    'general': 'General',
    'downloads': 'Downloads',
    'connection': 'Connection',
    'schedulerOffPeak': 'Off-Peak Window',
    'schedulerPeak': 'Peak Window',
    'schedulerAdd': 'Add Window',
    'pluginEnable': 'Enable',
    'pluginDisable': 'Disable',
    'pluginInstall': 'Install from folder',
    'settingsTitle': 'Settings',
    'themeDark': 'Dark',
    'themeLight': 'Light',
    'themeSystem': 'System',
    'comingSoon': 'Coming soon',
    'settingsTheme': 'Theme',
    'settingsLanguage': 'Language',
    'langEnglish': 'English',
    'langChinese': '中文',
    'settingSaveDir': 'Default save directory',
    'settingMaxConcurrent': 'Max concurrent downloads',
    'settingSpeedLimits': 'Speed limits',
    'settingProxy': 'Proxy',
    'settingNatUpnp': 'NAT/UPnP',
  },
  'zh-CN': {
    'appTitle': 'Velocita',
    'downloadsTab': '下载',
    'addUrl': '添加 URL',
    'refresh': '刷新',
    'cancel': '取消',
    'download': '下载',
    'all': '全部',
    'active': '下载中',
    'paused': '已暂停',
    'completed': '已完成',
    'error': '失败',
    'categories': '分类',
    'allDownloads': '全部下载',
    'uncategorized': '未分类',
    'movies': '电影',
    'music': '音乐',
    'archives': '压缩包',
    'documents': '文档',
    'programs': '程序',
    'images': '图片',
    'manageCategories': '管理分类',
    'engineConnected': '引擎：已连接',
    'engineDisconnected': '引擎：未连接',
    'noDownloads': '暂无下载 — 点击"添加 URL"。',
    'noActive': '无下载中任务。',
    'noPaused': '无已暂停任务。',
    'noCompleted': '无已完成任务。',
    'noError': '无失败任务。',
    'addDownload': '添加下载',
    'addDownloadTask': '添加下载任务',
    'urlHint': 'https://example.com/file.zip',
    'magnetHint': 'magnet:?xt=urn:btih:...',
    'urlInvalid': '必须是 http(s) URL',
    'magnetInvalid': '必须以 magnet:? 开头',
    'magnetMissingBtih': '缺少 urn:btih: 精确主题',
    'urlRequired': 'URL 必填',
    'chooseTorrent': '选择 .torrent 文件',
    'saveTo': '保存到',
    'saveToHint': '/保存/路径',
    'customDirectory': '自定义…',
    'tabUrl': '链接',
    'tabMagnet': '磁链',
    'tabTorrent': '种子',
    'magnetLabel': '磁链 URI',
    'settings': '设置',
    'scheduler': '调度器',
    'plugins': '插件',
    'general': '常规',
    'downloads': '下载',
    'connection': '连接',
    'schedulerOffPeak': '低峰时段',
    'schedulerPeak': '高峰时段',
    'schedulerAdd': '添加时段',
    'pluginEnable': '启用',
    'pluginDisable': '停用',
    'pluginInstall': '从文件夹安装',
    'settingsTitle': '设置',
    'themeDark': '深色',
    'themeLight': '浅色',
    'themeSystem': '跟随系统',
    'comingSoon': '敬请期待',
    'settingsTheme': '主题',
    'settingsLanguage': '语言',
    'langEnglish': 'English',
    'langChinese': '中文',
    'settingSaveDir': '默认保存目录',
    'settingMaxConcurrent': '最大并发下载数',
    'settingSpeedLimits': '速度限制',
    'settingProxy': '代理',
    'settingNatUpnp': 'NAT/UPnP',
  },
};

/// Reverse map: lookup the key from the English value (used by the
/// M3 fallback chain).
const Map<String, String> _catalog = {
  'appTitle': 'appTitle',
  'downloadsTab': 'downloadsTab',
  'addUrl': 'addUrl',
  'refresh': 'refresh',
  'cancel': 'cancel',
  'download': 'download',
  'all': 'all',
  'active': 'active',
  'paused': 'paused',
  'completed': 'completed',
  'error': 'error',
  'categories': 'categories',
  'allDownloads': 'allDownloads',
  'uncategorized': 'uncategorized',
  'movies': 'movies',
  'music': 'music',
  'archives': 'archives',
  'documents': 'documents',
  'programs': 'programs',
  'images': 'images',
  'manageCategories': 'manageCategories',
  'engineConnected': 'engineConnected',
  'engineDisconnected': 'engineDisconnected',
  'noDownloads': 'noDownloads',
  'noActive': 'noActive',
  'noPaused': 'noPaused',
  'noCompleted': 'noCompleted',
  'noError': 'noError',
  'addDownload': 'addDownload',
  'addDownloadTask': 'addDownloadTask',
  'urlHint': 'urlHint',
  'magnetHint': 'magnetHint',
  'urlInvalid': 'urlInvalid',
  'magnetInvalid': 'magnetInvalid',
  'magnetMissingBtih': 'magnetMissingBtih',
  'urlRequired': 'urlRequired',
  'chooseTorrent': 'chooseTorrent',
  'saveTo': 'saveTo',
  'saveToHint': 'saveToHint',
  'customDirectory': 'customDirectory',
  'tabUrl': 'tabUrl',
  'tabMagnet': 'tabMagnet',
  'tabTorrent': 'tabTorrent',
  'magnetLabel': 'magnetLabel',
  'settings': 'settings',
  'scheduler': 'scheduler',
  'plugins': 'plugins',
  'general': 'general',
  'downloads': 'downloads',
  'connection': 'connection',
  'schedulerOffPeak': 'schedulerOffPeak',
  'schedulerPeak': 'schedulerPeak',
  'schedulerAdd': 'schedulerAdd',
  'pluginEnable': 'pluginEnable',
  'pluginDisable': 'pluginDisable',
  'pluginInstall': 'pluginInstall',
  'settingsTitle': 'settingsTitle',
  'themeDark': 'themeDark',
  'themeLight': 'themeLight',
  'themeSystem': 'themeSystem',
  'comingSoon': 'comingSoon',
  'settingsTheme': 'settingsTheme',
  'settingsLanguage': 'settingsLanguage',
  'langEnglish': 'langEnglish',
  'langChinese': 'langChinese',
  'settingSaveDir': 'settingSaveDir',
  'settingMaxConcurrent': 'settingMaxConcurrent',
  'settingSpeedLimits': 'settingSpeedLimits',
  'settingProxy': 'settingProxy',
  'settingNatUpnp': 'settingNatUpnp',
};
