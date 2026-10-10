/// Public surface for the HLS (.m3u8) downloader feature.
library;

export 'domain/hls_models.dart'
    show
        HlsSegment,
        HlsVariant,
        HlsPlaylist,
        HlsJob,
        HlsCancelled,
        HlsParseException,
        HlsUnsupportedFeature,
        HlsFetchException,
        HlsMergerException;
export 'domain/hls_url.dart'
    show isM3u8, baseNameForHlsUrl, sanitizeFileName;
export 'presentation/hls_downloader.dart'
    show
        HlsDownloader,
        HlsEvent,
        hlsDownloaderProvider,
        hlsEventsProvider;
