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
  String get settingStartHiddenToTray => _t(_catalog['settingStartHiddenToTray']!);
  String get settingStartHiddenToTrayHint => _t(_catalog['settingStartHiddenToTrayHint']!);
  String get addTask => _t(_catalog['addTask']!);
  String get pauseTask => _t(_catalog['pauseTask']!);
  String get resumeTask => _t(_catalog['resumeTask']!);
  String get openFolder => _t(_catalog['openFolder']!);
  String get removeFromHistory => _t(_catalog['removeFromHistory']!);
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
  String get other => _t(_catalog['other']!);
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
  String get close => _t(_catalog['close']!);
  String get defaultCategoriesTitle => _t(_catalog['defaultCategoriesTitle']!);
  String get defaultCategoriesIntro =>
      _t(_catalog['defaultCategoriesIntro']!);
  String get defaultCategoriesFooter =>
      _t(_catalog['defaultCategoriesFooter']!);
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
  String get startup => _t(_catalog['startup']!);
  String get advanced => _t(_catalog['advanced']!);
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
  String get settingSaveDirHint => _t(_catalog['settingSaveDirHint']!);
  String get settingSaveDirBrowse => _t(_catalog['settingSaveDirBrowse']!);
  String get settingMaxConcurrentHint =>
      _t(_catalog['settingMaxConcurrentHint']!);
  String get settingSpeedLimitLabel =>
      _t(_catalog['settingSpeedLimitLabel']!);
  String get settingSpeedLimitHint =>
      _t(_catalog['settingSpeedLimitHint']!);
  String get settingSpeedLimitUnlimited =>
      _t(_catalog['settingSpeedLimitUnlimited']!);
  String get settingValueUnlimited =>
      _t(_catalog['settingValueUnlimited']!);
  String get settingProxyOff => _t(_catalog['settingProxyOff']!);
  String get settingProxyHttp => _t(_catalog['settingProxyHttp']!);
  String get settingProxySocks5 => _t(_catalog['settingProxySocks5']!);
  String get settingProxySocks5Unsupported =>
      _t(_catalog['settingProxySocks5Unsupported']!);
  String get settingProxyHost => _t(_catalog['settingProxyHost']!);
  String get settingProxyPort => _t(_catalog['settingProxyPort']!);
  String get settingProxyUsername =>
      _t(_catalog['settingProxyUsername']!);
  String get settingProxyPassword =>
      _t(_catalog['settingProxyPassword']!);
  String get settingProxyBypass => _t(_catalog['settingProxyBypass']!);
  String get settingProxyAuthOptional =>
      _t(_catalog['settingProxyAuthOptional']!);
  String get settingProxyIncomplete =>
      _t(_catalog['settingProxyIncomplete']!);
  String get settingProxyApplied =>
      _t(_catalog['settingProxyApplied']!);
  String get settingNatOff => _t(_catalog['settingNatOff']!);
  String get settingNatUpnpOn => _t(_catalog['settingNatUpnpOn']!);
  String get settingSplit => _t(_catalog['settingSplit']!);
  String get settingSplitHint => _t(_catalog['settingSplitHint']!);
  String get settingSplitAppliesToNew =>
      _t(_catalog['settingSplitAppliesToNew']!);
  String get settingMaxConnPerServer =>
      _t(_catalog['settingMaxConnPerServer']!);
  String get settingMaxConnPerServerHint =>
      _t(_catalog['settingMaxConnPerServerHint']!);
  String get settingAutoStart => _t(_catalog['settingAutoStart']!);
  String get settingAutoStartHint =>
      _t(_catalog['settingAutoStartHint']!);
  String get settingSilentStart => _t(_catalog['settingSilentStart']!);
  String get settingSilentStartHint =>
      _t(_catalog['settingSilentStartHint']!);
  String get newCategory => _t(_catalog['newCategory']!);
  String get newChildCategory => _t(_catalog['newChildCategory']!);
  String get renameCategory => _t(_catalog['renameCategory']!);
  String get editCategory => _t(_catalog['editCategory']!);
  String get deleteCategory => _t(_catalog['deleteCategory']!);
  String get categoryName => _t(_catalog['categoryName']!);
  String get categoryIcon => _t(_catalog['categoryIcon']!);
  String get categoryExtensions => _t(_catalog['categoryExtensions']!);
  String get categoryExtensionsHint =>
      _t(_catalog['categoryExtensionsHint']!);
  String get categorySites => _t(_catalog['categorySites']!);
  String get categorySitesHint => _t(_catalog['categorySitesHint']!);
  String get categoryParent => _t(_catalog['categoryParent']!);
  String get categorySaveDir => _t(_catalog['categorySaveDir']!);
  String get deleteBlockedDefault =>
      _t(_catalog['deleteBlockedDefault']!);
  String get deleteBlockedNonEmpty =>
      _t(_catalog['deleteBlockedNonEmpty']!);
  String get confirmDeleteCategory =>
      _t(_catalog['confirmDeleteCategory']!);
  String get save => _t(_catalog['save']!);
  String get batchOps => _t(_catalog['batchOps']!);
  String get selectAll => _t(_catalog['selectAll']!);
  String get invertSelection => _t(_catalog['invertSelection']!);
  String get clearSelection => _t(_catalog['clearSelection']!);
  String get selectedCount => _t(_catalog['selectedCount']!);
  String get customizeColumns => _t(_catalog['customizeColumns']!);
  String get columnFilename => _t(_catalog['columnFilename']!);
  String get columnStatus => _t(_catalog['columnStatus']!);
  String get columnProgress => _t(_catalog['columnProgress']!);
  String get columnSpeed => _t(_catalog['columnSpeed']!);
  String get columnSize => _t(_catalog['columnSize']!);
  String get columnAdded => _t(_catalog['columnAdded']!);
  String get columnLocked => _t(_catalog['columnLocked']!);
  String get moveUp => _t(_catalog['moveUp']!);
  String get moveDown => _t(_catalog['moveDown']!);
  String get resetColumns => _t(_catalog['resetColumns']!);
  String get browserIntegration => _t(_catalog['browserIntegration']!);
  String get browserIntegrationEnabled =>
      _t(_catalog['browserIntegrationEnabled']!);
  String get browserIntegrationEnabledHint =>
      _t(_catalog['browserIntegrationEnabledHint']!);
  String get browserIntegrationDisabled =>
      _t(_catalog['browserIntegrationDisabled']!);
  String get browserIntegrationStarting =>
      _t(_catalog['browserIntegrationStarting']!);
  String get browserIntegrationGenerateRegFile =>
      _t(_catalog['browserIntegrationGenerateRegFile']!);
  String get browserIntegrationRegFileWritten =>
      _t(_catalog['browserIntegrationRegFileWritten']!);
  String get copy => _t(_catalog['copy']!);
  String get browserIntegrationConfirm =>
      _t(_catalog['browserIntegrationConfirm']!);
  String get browserIntegrationConfirmHint =>
      _t(_catalog['browserIntegrationConfirmHint']!);
  String get browserIntegrationListening =>
      _t(_catalog['browserIntegrationListening']!);
  String get browserIntegrationInstallFailed =>
      _t(_catalog['browserIntegrationInstallFailed']!);
  String get installForChrome => _t(_catalog['installForChrome']!);
  String get installForEdge => _t(_catalog['installForEdge']!);
  String get installForFirefox => _t(_catalog['installForFirefox']!);
  String get uninstallIntegration =>
      _t(_catalog['uninstallIntegration']!);
  String get installStepsChrome1 => _t(_catalog['installStepsChrome1']!);
  String get installStepsChrome2 => _t(_catalog['installStepsChrome2']!);
  String get installStepsChrome3 => _t(_catalog['installStepsChrome3']!);
  String get installStepsChrome4 => _t(_catalog['installStepsChrome4']!);
  String get installStepsEdge1 => _t(_catalog['installStepsEdge1']!);
  String get installStepsEdge2 => _t(_catalog['installStepsEdge2']!);
  String get installStepsEdge3 => _t(_catalog['installStepsEdge3']!);
  String get installStepsEdge4 => _t(_catalog['installStepsEdge4']!);
  String get installStepsFirefox1 =>
      _t(_catalog['installStepsFirefox1']!);
  String get installStepsFirefox2 =>
      _t(_catalog['installStepsFirefox2']!);
  String get installStepsFirefox3 =>
      _t(_catalog['installStepsFirefox3']!);
  String get installStepsFirefox4 =>
      _t(_catalog['installStepsFirefox4']!);
  String get browserIntegrationInstalledHint =>
      _t(_catalog['browserIntegrationInstalledHint']!);
  String browserIntegrationInstalledHintText(String browser) =>
      _t(_catalog['browserIntegrationInstalledHint']!).replaceAll(
            '{browser}',
            browser,
          );

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
    'settingStartHiddenToTray': 'Start hidden in tray',
    'settingStartHiddenToTrayHint': 'Velocita launches to the system tray only; click the tray icon to show the main window.',
    'addTask': 'Add Task',
    'pauseTask': 'Pause',
    'resumeTask': 'Resume',
    'openFolder': 'Open folder',
    'removeFromHistory': 'Remove from history',
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
    'other': 'Other',
    'manageCategories': 'Manage categories',
    'engineConnected': 'Engine: Connected',
    'engineDisconnected': 'Engine: Disconnected',
    'noDownloads': 'No downloads yet — click "Add Task".',
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
    'close': 'Close',
    'defaultCategoriesTitle': 'Default categories',
    'defaultCategoriesIntro':
        'Velocita ships 6 default categories with extension patterns:',
    'defaultCategoriesFooter':
        'New downloads are routed into the matching category folder.',
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
    'startup': 'Startup',
    'advanced': 'Advanced',
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
    'settingSaveDirHint': 'Where new downloads land when no category matches',
    'settingSaveDirBrowse': 'Browse…',
    'settingMaxConcurrentHint':
        'Maximum number of downloads aria2 will run at the same time',
    'settingSpeedLimitLabel': 'Overall download limit',
    'settingSpeedLimitHint':
        'Cap the total bandwidth used by all active downloads',
    'settingSpeedLimitUnlimited': 'Unlimited',
    'settingValueUnlimited': '∞',
    'settingProxyOff': 'Off',
    'settingProxyHttp': 'HTTP',
    'settingProxySocks5': 'SOCKS5',
    'settingProxySocks5Unsupported':
        'SOCKS5 is not supported by this aria2 build — only HTTP proxies work.',
    'settingProxyHost': 'Host',
    'settingProxyPort': 'Port',
    'settingProxyUsername': 'Username',
    'settingProxyPassword': 'Password',
    'settingProxyBypass': 'No-proxy hosts',
    'settingProxyAuthOptional': 'Optional',
    'settingProxyIncomplete': 'Host and port are required',
    'settingProxyApplied': 'Proxy applied to engine',
    'settingNatOff': 'Off',
    'settingNatUpnpOn': 'UPnP',
    'settingSplit': 'Connections per file',
    'settingSplitHint':
        'How many parallel ranges aria2 splits each file into (HTTP/FTP)',
    'settingSplitAppliesToNew':
        'Applies to new downloads — already-running tasks keep their layout',
    'settingMaxConnPerServer': 'Max connections per server',
    'settingMaxConnPerServerHint':
        'Cap on concurrent connections to the same server',
    'settingAutoStart': 'Start Velocita at sign-in',
    'settingAutoStartHint':
        'Launch Velocita automatically when you log in to Windows',
    'settingSilentStart': 'Start minimized to tray',
    'settingSilentStartHint':
        'When launched automatically, start hidden in the tray instead of opening a window',
    'newCategory': 'New category',
    'newChildCategory': 'New sub-category',
    'renameCategory': 'Rename',
    'editCategory': 'Edit',
    'deleteCategory': 'Delete',
    'categoryName': 'Name',
    'categoryIcon': 'Icon',
    'categoryExtensions': 'File extensions',
    'categoryExtensionsHint':
        'e.g. .iso .img, separated by space or comma',
    'categorySites': 'Default from these sites',
    'categorySitesHint': 'One host per line, e.g. github.com',
    'categoryParent': 'Parent category',
    'categorySaveDir': 'Save folder',
    'deleteBlockedDefault': 'Default categories cannot be deleted',
    'deleteBlockedNonEmpty': 'Remove its sub-categories first',
    'confirmDeleteCategory':
        'Delete this category? Files on disk will be kept.',
    'save': 'Save',
    'batchOps': 'Batch operations',
    'selectAll': 'Select all',
    'invertSelection': 'Invert',
    'clearSelection': 'Clear',
    'selectedCount': 'N selected',
    'customizeColumns': 'Customize columns',
    'columnFilename': 'Filename',
    'columnStatus': 'Status',
    'columnProgress': 'Progress',
    'columnSpeed': 'Speed',
    'columnSize': 'Size',
    'columnAdded': 'Added',
    'columnLocked': 'Locked',
    'moveUp': 'Move up',
    'moveDown': 'Move down',
    'resetColumns': 'Reset',
    'browserIntegration': 'Browser integration',
    'browserIntegrationEnabled': 'Enable browser integration',
    'browserIntegrationEnabledHint':
        'When on, Velocita listens on a local port and accepts downloads from Chrome / Edge / Firefox extensions. When off, no listening socket is opened.',
    'browserIntegrationDisabled': 'Disabled — local IPC server is not running',
    'browserIntegrationStarting': 'Starting…',
    'browserIntegrationGenerateRegFile': 'Generate registry file…',
    'browserIntegrationRegFileWritten':
        'Registry file written — double-click it in Explorer to install.',
    'copy': 'Copy',
    'browserIntegrationConfirm':
        'Show confirmation popup for browser-sent downloads',
    'browserIntegrationConfirmHint':
        'When on, every download sent from a browser shows a dialog first. When off, the task is added to the queue immediately.',
    'browserIntegrationListening':
        'Velocita is listening on the local IPC port',
    'browserIntegrationInstallFailed': 'Browser integration install failed',
    'installForChrome': 'Install for',
    'installForEdge': 'Install for',
    'installForFirefox': 'Install for',
    'uninstallIntegration': 'Uninstall',
    'browserIntegrationInstalledHint':
        'Native Messaging host registered. To finish installing the {browser} extension:',
    'installStepsChrome1':
        'Open chrome://extensions (we have opened it for you).',
    'installStepsChrome2':
        'Toggle "Developer mode" in the top-right corner.',
    'installStepsChrome3':
        'Click "Load unpacked" and pick the velocita/extensions/chrome folder.',
    'installStepsChrome4':
        'Right-click any link in Chrome then "Download with Velocita".',
    'installStepsEdge1':
        'Open edge://extensions (we have opened it for you).',
    'installStepsEdge2':
        'Toggle "Developer mode" in the bottom-left corner.',
    'installStepsEdge3':
        'Click "Load unpacked" and pick the velocita/extensions/edge folder.',
    'installStepsEdge4':
        'Right-click any link in Edge then "Download with Velocita".',
    'installStepsFirefox1':
        'Open about:debugging#/runtime/this-firefox (we have opened it for you).',
    'installStepsFirefox2': 'Click "Load Temporary Add-on".',
    'installStepsFirefox3':
        'Pick the manifest.json inside velocita/extensions/firefox.',
    'installStepsFirefox4':
        'For permanent install, submit the extension to addons.mozilla.org.',
  },
  'zh-CN': {
    'appTitle': 'Velocita',
    'downloadsTab': '下载',
    'settingStartHiddenToTray': '启动时最小化到托盘',
    'settingStartHiddenToTrayHint': '启动后只显示托盘图标，不显示主窗口；点击托盘图标再显示主窗口。',
    'addTask': '添加下载任务',
    'pauseTask': '暂停',
    'resumeTask': '继续',
    'openFolder': '打开所在文件夹',
    'removeFromHistory': '从记录中删除',
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
    'other': '其他',
    'manageCategories': '管理分类',
    'engineConnected': '引擎：已连接',
    'engineDisconnected': '引擎：未连接',
    'noDownloads': '暂无下载 — 点击"添加下载任务"。',
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
    'close': '关闭',
    'defaultCategoriesTitle': '默认分类',
    'defaultCategoriesIntro': 'Velocita 内置 6 个默认分类，按扩展名自动匹配：',
    'defaultCategoriesFooter': '新下载会自动路由到匹配的分类文件夹。',
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
    'startup': '启动',
    'advanced': '高级',
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
    'settingSaveDirHint': '未匹配到分类时新下载的保存位置',
    'settingSaveDirBrowse': '浏览…',
    'settingMaxConcurrentHint': 'aria2 同时运行的最大下载任务数',
    'settingSpeedLimitLabel': '总下载速度上限',
    'settingSpeedLimitHint': '限制所有活跃下载的总带宽',
    'settingSpeedLimitUnlimited': '不限速',
    'settingValueUnlimited': '∞',
    'settingProxyOff': '关闭',
    'settingProxyHttp': 'HTTP',
    'settingProxySocks5': 'SOCKS5',
    'settingProxySocks5Unsupported':
        '当前 aria2 版本不支持 SOCKS5，仅支持 HTTP 代理。',
    'settingProxyHost': '主机',
    'settingProxyPort': '端口',
    'settingProxyUsername': '用户名',
    'settingProxyPassword': '密码',
    'settingProxyBypass': '不走代理的地址',
    'settingProxyAuthOptional': '可选',
    'settingProxyIncomplete': '需要填写主机和端口',
    'settingProxyApplied': '代理已下发到引擎',
    'settingNatOff': '关闭',
    'settingNatUpnpOn': 'UPnP',
    'settingSplit': '单文件并发连接数',
    'settingSplitHint': 'aria2 把每个文件切成的并行段数（HTTP/FTP）',
    'settingSplitAppliesToNew': '仅对新建下载生效，已在跑的任务不会重新分块',
    'settingMaxConnPerServer': '每服务器最大连接数',
    'settingMaxConnPerServerHint': '对同一服务器的最大并发连接数上限',
    'settingAutoStart': '开机自启',
    'settingAutoStartHint': '登录 Windows 时自动启动 Velocita',
    'settingSilentStart': '静默启动',
    'settingSilentStartHint': '自动启动时隐藏到托盘，不弹出主窗口',
    'newCategory': '新建分类',
    'newChildCategory': '新建子分类',
    'renameCategory': '重命名',
    'editCategory': '编辑',
    'deleteCategory': '删除',
    'categoryName': '名称',
    'categoryIcon': '图标',
    'categoryExtensions': '文件扩展名',
    'categoryExtensionsHint': '例如 .iso .img，空格或逗号分隔',
    'categorySites': '来自以下站点的默认分类',
    'categorySitesHint': '每行一个域名，例如 github.com',
    'categoryParent': '父分类',
    'categorySaveDir': '保存文件夹',
    'deleteBlockedDefault': '默认分类不允许删除',
    'deleteBlockedNonEmpty': '请先删除其子分类',
    'confirmDeleteCategory': '确定删除该分类？磁盘上的文件将保留。',
    'save': '保存',
    'batchOps': '批量操作',
    'selectAll': '全选',
    'invertSelection': '反选',
    'clearSelection': '取消选择',
    'selectedCount': '已选 N 项',
    'customizeColumns': '自定义表头',
    'columnFilename': '文件名',
    'columnStatus': '状态',
    'columnProgress': '进度',
    'columnSpeed': '速度',
    'columnSize': '大小',
    'columnAdded': '添加时间',
    'columnLocked': '已锁定',
    'moveUp': '上移',
    'moveDown': '下移',
    'resetColumns': '重置',
    'browserIntegration': '浏览器集成',
    'browserIntegrationEnabled': '启用浏览器集成',
    'browserIntegrationEnabledHint':
        '开启时，Velocita 在本地端口监听，接收来自 Chrome / Edge / Firefox 扩展的下载；关闭时，不打开任何监听套接字。',
    'browserIntegrationDisabled': '已禁用 — 本地 IPC 服务未运行',
    'browserIntegrationStarting': '正在启动…',
    'browserIntegrationGenerateRegFile': '生成注册表文件…',
    'browserIntegrationRegFileWritten': '注册表文件已生成 — 在资源管理器中双击即可安装。',
    'copy': '复制',
    'browserIntegrationConfirm': '对浏览器发来的下载显示确认弹窗',
    'browserIntegrationConfirmHint':
        '开启时，浏览器发来的每个下载都会先弹出确认框；关闭时直接入队。',
    'browserIntegrationListening': 'Velocita 正在本地 IPC 端口监听',
    'browserIntegrationInstallFailed': '浏览器集成安装失败',
    'installForChrome': '安装到',
    'installForEdge': '安装到',
    'installForFirefox': '安装到',
    'uninstallIntegration': '卸载',
    'browserIntegrationInstalledHint': 'Native Messaging 主机已注册。要完成 {browser} 扩展的安装：',
    'installStepsChrome1': '打开 chrome://extensions（已为你打开）。',
    'installStepsChrome2': '在右上角打开"开发者模式"。',
    'installStepsChrome3': '点击"加载已解压的扩展程序"，选择 velocita/extensions/chrome 文件夹。',
    'installStepsChrome4': '在 Chrome 中右键任意链接，选择"使用 Velocita 下载"。',
    'installStepsEdge1': '打开 edge://extensions（已为你打开）。',
    'installStepsEdge2': '在左下角打开"开发人员模式"。',
    'installStepsEdge3': '点击"加载解压缩的扩展"，选择 velocita/extensions/edge 文件夹。',
    'installStepsEdge4': '在 Edge 中右键任意链接，选择"使用 Velocita 下载"。',
    'installStepsFirefox1': '打开 about:debugging#/runtime/this-firefox（已为你打开）。',
    'installStepsFirefox2': '点击"临时载入附加组件…"。',
    'installStepsFirefox3': '选择 velocita/extensions/firefox 内的 manifest.json。',
    'installStepsFirefox4': '如需永久安装，请提交到 addons.mozilla.org 签名。',
  },
};

/// Reverse map: lookup the key from the English value (used by the
/// M3 fallback chain).
const Map<String, String> _catalog = {
  'appTitle': 'appTitle',
  'downloadsTab': 'downloadsTab',
  'settingStartHiddenToTray': 'settingStartHiddenToTray',
  'settingStartHiddenToTrayHint': 'settingStartHiddenToTrayHint',
  'addTask': 'addTask',
  'pauseTask': 'pauseTask',
  'resumeTask': 'resumeTask',
  'openFolder': 'openFolder',
  'removeFromHistory': 'removeFromHistory',
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
  'other': 'other',
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
  'close': 'close',
  'defaultCategoriesTitle': 'defaultCategoriesTitle',
  'defaultCategoriesIntro': 'defaultCategoriesIntro',
  'defaultCategoriesFooter': 'defaultCategoriesFooter',
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
  'startup': 'startup',
  'advanced': 'advanced',
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
  'settingSaveDirHint': 'settingSaveDirHint',
  'settingSaveDirBrowse': 'settingSaveDirBrowse',
  'settingMaxConcurrentHint': 'settingMaxConcurrentHint',
  'settingSpeedLimitLabel': 'settingSpeedLimitLabel',
  'settingSpeedLimitHint': 'settingSpeedLimitHint',
  'settingSpeedLimitUnlimited': 'settingSpeedLimitUnlimited',
  'settingValueUnlimited': 'settingValueUnlimited',
  'settingProxyOff': 'settingProxyOff',
  'settingProxyHttp': 'settingProxyHttp',
  'settingProxySocks5': 'settingProxySocks5',
  'settingProxySocks5Unsupported': 'settingProxySocks5Unsupported',
  'settingProxyHost': 'settingProxyHost',
  'settingProxyPort': 'settingProxyPort',
  'settingProxyUsername': 'settingProxyUsername',
  'settingProxyPassword': 'settingProxyPassword',
  'settingProxyBypass': 'settingProxyBypass',
  'settingProxyAuthOptional': 'settingProxyAuthOptional',
  'settingProxyIncomplete': 'settingProxyIncomplete',
  'settingProxyApplied': 'settingProxyApplied',
  'settingNatOff': 'settingNatOff',
  'settingNatUpnpOn': 'settingNatUpnpOn',
  'settingSplit': 'settingSplit',
  'settingSplitHint': 'settingSplitHint',
  'settingSplitAppliesToNew': 'settingSplitAppliesToNew',
  'settingMaxConnPerServer': 'settingMaxConnPerServer',
  'settingMaxConnPerServerHint': 'settingMaxConnPerServerHint',
  'settingAutoStart': 'settingAutoStart',
  'settingAutoStartHint': 'settingAutoStartHint',
  'settingSilentStart': 'settingSilentStart',
  'settingSilentStartHint': 'settingSilentStartHint',
  'newCategory': 'newCategory',
  'newChildCategory': 'newChildCategory',
  'renameCategory': 'renameCategory',
  'editCategory': 'editCategory',
  'deleteCategory': 'deleteCategory',
  'categoryName': 'categoryName',
  'categoryIcon': 'categoryIcon',
  'categoryExtensions': 'categoryExtensions',
  'categoryExtensionsHint': 'categoryExtensionsHint',
  'categorySites': 'categorySites',
  'categorySitesHint': 'categorySitesHint',
  'categoryParent': 'categoryParent',
  'categorySaveDir': 'categorySaveDir',
  'deleteBlockedDefault': 'deleteBlockedDefault',
  'deleteBlockedNonEmpty': 'deleteBlockedNonEmpty',
  'confirmDeleteCategory': 'confirmDeleteCategory',
  'save': 'save',
  'batchOps': 'batchOps',
  'selectAll': 'selectAll',
  'invertSelection': 'invertSelection',
  'clearSelection': 'clearSelection',
  'selectedCount': 'selectedCount',
  'customizeColumns': 'customizeColumns',
  'columnFilename': 'columnFilename',
  'columnStatus': 'columnStatus',
  'columnProgress': 'columnProgress',
  'columnSpeed': 'columnSpeed',
  'columnSize': 'columnSize',
  'columnAdded': 'columnAdded',
  'columnLocked': 'columnLocked',
  'moveUp': 'moveUp',
  'moveDown': 'moveDown',
  'resetColumns': 'resetColumns',
  'browserIntegration': 'browserIntegration',
  'browserIntegrationEnabled': 'browserIntegrationEnabled',
  'browserIntegrationEnabledHint': 'browserIntegrationEnabledHint',
  'browserIntegrationDisabled': 'browserIntegrationDisabled',
  'browserIntegrationStarting': 'browserIntegrationStarting',
  'browserIntegrationGenerateRegFile': 'browserIntegrationGenerateRegFile',
  'browserIntegrationRegFileWritten': 'browserIntegrationRegFileWritten',
  'copy': 'copy',
  'browserIntegrationConfirm': 'browserIntegrationConfirm',
  'browserIntegrationConfirmHint': 'browserIntegrationConfirmHint',
  'browserIntegrationListening': 'browserIntegrationListening',
  'browserIntegrationInstallFailed': 'browserIntegrationInstallFailed',
  'installForChrome': 'installForChrome',
  'installForEdge': 'installForEdge',
  'installForFirefox': 'installForFirefox',
  'uninstallIntegration': 'uninstallIntegration',
  'browserIntegrationInstalledHint': 'browserIntegrationInstalledHint',
  'installStepsChrome1': 'installStepsChrome1',
  'installStepsChrome2': 'installStepsChrome2',
  'installStepsChrome3': 'installStepsChrome3',
  'installStepsChrome4': 'installStepsChrome4',
  'installStepsEdge1': 'installStepsEdge1',
  'installStepsEdge2': 'installStepsEdge2',
  'installStepsEdge3': 'installStepsEdge3',
  'installStepsEdge4': 'installStepsEdge4',
  'installStepsFirefox1': 'installStepsFirefox1',
  'installStepsFirefox2': 'installStepsFirefox2',
  'installStepsFirefox3': 'installStepsFirefox3',
  'installStepsFirefox4': 'installStepsFirefox4',
};
