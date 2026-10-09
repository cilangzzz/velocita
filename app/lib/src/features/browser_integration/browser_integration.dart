/// Public surface for the browser-integration feature.
///
/// Per `docs/rule/flutter_rule/01-architecture.md` §"Feature module
/// contract", every feature folder MUST contain a barrel file that
/// re-exports the public surface only. Internal files (data/, domain/)
/// stay private.
library;

export 'domain/add_request.dart' show AddRequest, AddSource;
export 'domain/browser_integration_settings.dart'
    show BrowserIntegrationSettings, BrowserKind;
export 'data/browser_integration_service.dart'
    show BrowserIntegrationService;
export 'data/browser_integration_controller.dart'
    show
        BrowserIntegrationController,
        browserIntegrationControllerProvider,
        initialBrowserIntegrationServiceProvider,
        browserIntegrationPortProvider;
export 'data/browser_launcher.dart' show openInBrowser;
export 'data/host_installer.dart'
    show
        kHostName,
        extensionsPageUrl,
        installFor,
        uninstallFor,
        uninstallAll,
        selfHeal,
        selfHealUrlScheme,
        writeRegFile;
export 'data/host_installer_windows.dart'
    show registerVelocitaUrlScheme, unregisterVelocitaUrlScheme;
export 'data/browser_integration_settings_provider.dart'
    show
        browserIntegrationSettingsProvider,
        BrowserIntegrationSettingsNotifier;
export 'data/pending_add_requests_provider.dart'
    show pendingAddRequestsProvider;
export 'data/window_bridge.dart'
    show
        AddTaskPayload,
        AddTaskResult,
        spawnAddTaskSubWindow,
        addTaskResultHandler,
        onSubWindowAddTaskResult;
export 'presentation/pending_add_request_listener.dart'
    show PendingAddRequestListener;
export 'presentation/browser_integration_section.dart'
    show BrowserIntegrationSection;
export 'presentation/install_instructions_dialog.dart'
    show InstallInstructionsDialog;
