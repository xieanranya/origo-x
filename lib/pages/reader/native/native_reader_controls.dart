part of 'native_reader_page.dart';

extension _NativeReaderControls on _NativeReaderPageState {
  void _markReaderAloudForManualPageTurn() {
    final session = context.read<ReaderAloudSession?>();
    if (session?.sourceId == 'local:${widget.book.id}' &&
        session?.controller != null &&
        _readerAloudController != session!.controller) {
      _readerAloudController?.removeListener(_onReaderAloudChanged);
      _readerAloudController = session.controller;
      _readerAloudController!.addListener(_onReaderAloudChanged);
    }
    final controller = _readerAloudController;
    if (controller?.isActive == true) {
      _readerAloudNavigationDetached = true;
      ++_readerAloudNavigationRevision;
      // Do not let an already queued spoken-position restore overwrite the
      // page committed by this gesture on the next build.
      if (_pageMode != NativePageMode.verticalScroll) {
        _restoreAnchorAfterLayout = false;
        _pendingRestoreChapterIndex = null;
        ++_verticalScrollRevision;
      }
    }
    _restartReaderAloudAfterManualPageTurn =
        context.read<ReaderAloudService?>()?.followPageTurns == true &&
        (controller?.state == ReaderAloudPlaybackState.playing ||
            controller?.state == ReaderAloudPlaybackState.loading);
  }

  void _restartReaderAloudFromCurrentPageAfterManualTurn({
    ReaderAloudPosition? position,
  }) {
    if (!_restartReaderAloudAfterManualPageTurn) return;
    _restartReaderAloudAfterManualPageTurn = false;
    final controller = _readerAloudController;
    if (controller == null ||
        !controller.isActive ||
        controller.state == ReaderAloudPlaybackState.paused) {
      return;
    }
    final revision = _readerAloudNavigationRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          revision == _readerAloudNavigationRevision &&
          context.read<ReaderAloudService?>()?.followPageTurns == true &&
          controller.isActive &&
          controller.state != ReaderAloudPlaybackState.paused) {
        final offset = _visiblePages.isEmpty
            ? (_anchorOffset ?? 0)
            : _visiblePages[_pageIndex.clamp(0, _visiblePages.length - 1)]
                  .startOffset;
        // Capture this route's committed page, not a source callback retained
        // by the app session from a previously closed reader.
        unawaited(
          controller
              .start(
                position:
                    position ??
                    ReaderAloudPosition(
                      chapterIndex: _chapterIndex,
                      offset: offset,
                    ),
              )
              .then((_) {
                if (mounted && revision == _readerAloudNavigationRevision) {
                  _readerAloudNavigationDetached = false;
                }
              }),
        );
      }
    });
  }

  String _readerThemeName(BuildContext context, String themeId) {
    final customName = ReaderThemes.customThemeById(themeId)?.name.trim();
    if (customName != null && customName.isNotEmpty) return customName;
    switch (themeId) {
      case ReaderThemes.systemId:
        return context.l10n.readerThemeFollowSystem;
      case 'paper':
        return context.l10n.readerThemePaper;
      case 'green':
        return context.l10n.readerThemeGreen;
      case 'navy':
        return context.l10n.readerThemeNavy;
      case 'night':
        return context.l10n.readerThemeNight;
      case 'pureBlack':
        return context.l10n.readerThemePureBlack;
      case 'parchment':
        return context.l10n.readerThemeParchment;
      case 'xian_tan_light':
        return '闲潭梦落花 日';
      case 'xian_tan_dark':
        return '闲潭梦落花 夜';
      case 'ye_se_dark':
        return '夜色·月 夜';
      case ReaderCustomTheme.themeId:
        return context.l10n.readerThemeCustom;
      default:
        return context.l10n.readerThemeDay;
    }
  }

  ReaderAloudController? _ensureReaderAloudController() {
    final existing = _readerAloudController;
    if (existing != null) return existing;
    ReaderAloudService aloudService;
    try {
      aloudService = context.read<ReaderAloudService>();
    } on ProviderNotFoundException {
      return null;
    }
    final session = context.read<ReaderAloudSession>();
    final controller = session.acquire(
      sourceId: 'local:${widget.book.id}',
      create: () => ReaderAloudController(
        engine: aloudService,
        source: CallbackReaderAloudSource(
          bookTitle: widget.book.title,
          chapterCount: () => _loadedChapters.length,
          currentPosition: () async {
            final chapterIndex = _chapterIndex
                .clamp(0, math.max(0, _loadedChapters.length - 1))
                .toInt();
            var offset = _anchorOffset ?? 0;
            if (_pageMode == NativePageMode.verticalScroll &&
                _visibleContinuousParts.isNotEmpty) {
              offset =
                  _visibleContinuousParts[_pageIndex.clamp(
                        0,
                        _visibleContinuousParts.length - 1,
                      )]
                      .content
                      .startOffset;
            } else if (_visiblePages.isNotEmpty) {
              offset =
                  _visiblePages[_pageIndex.clamp(0, _visiblePages.length - 1)]
                      .startOffset;
            }
            return ReaderAloudPosition(
              chapterIndex: chapterIndex,
              offset: offset,
            );
          },
          loadChapter: (index) async {
            if (index < 0 || index >= _loadedChapters.length) return null;
            final chapter = _loadedChapters[index];
            await chapter.loadTextAsync();
            return ReaderAloudChapter(
              index: index,
              id: chapter.id,
              title: chapter.title,
              text: chapter.plainText,
            );
          },
          revealPosition: _revealReaderAloudPosition,
          persistPosition: _persistReaderAloudPosition,
        ),
      ),
    )..addListener(_onReaderAloudChanged);
    _readerAloudController = controller;
    return controller;
  }

  void _onReaderAloudChanged() {
    final active = _readerAloudController?.isActive ?? false;
    final highlight = _readerAloudController?.highlight;
    if (!mounted) return;
    if (!active) _readerAloudNavigationDetached = false;
    if (_readerAloudController?.state == ReaderAloudPlaybackState.playing ||
        _readerAloudController?.state == ReaderAloudPlaybackState.loading) {
      _pauseAutoPageTurn();
    }
    final error = _readerAloudController?.lastError;
    if (error != null) {
      showSideToast(context, '朗读启动失败：$error', kind: SideToastKind.error);
    }
    if (active == _readerAloudActive && highlight == _readerAloudHighlight) {
      return;
    }
    _setReaderState(() {
      _readerAloudActive = active;
      _readerAloudHighlight = highlight;
    });
  }

  Future<void> _locateReaderAloud() async {
    final session = context.read<ReaderAloudSession?>();
    if (session?.sourceId != 'local:${widget.book.id}') return;
    final controller = session?.controller;
    final highlight = controller?.highlight;
    if (controller == null || highlight == null) return;
    // A reopened reader must subscribe to the existing session, not acquire a
    // new one or use reveal callbacks captured by a disposed reader route.
    if (_readerAloudController != controller) {
      _readerAloudController?.removeListener(_onReaderAloudChanged);
      _readerAloudController = controller;
      controller.addListener(_onReaderAloudChanged);
    }
    _onReaderAloudChanged();
    try {
      await _revealReaderAloudPosition(
        ReaderAloudPosition(
          chapterIndex: highlight.chapterIndex,
          offset: highlight.startOffset,
        ),
        force: true,
      );
    } catch (_) {
      if (mounted) {
        showSideToast(context, switch (Localizations.localeOf(
          context,
        ).languageCode) {
          'en' => 'Could not locate the reading position. Please retry.',
          'ja' => '読み上げ位置に移動できませんでした。再試行してください。',
          _ => '定位朗读失败，请重试',
        }, kind: SideToastKind.error);
      }
    }
  }

  Future<void> _revealReaderAloudPosition(
    ReaderAloudPosition position, {
    bool force = false,
  }) async {
    if (!mounted || _loadedChapters.isEmpty) return;
    if (force) {
      _readerAloudNavigationDetached = false;
      ++_readerAloudNavigationRevision;
    } else if (_readerAloudNavigationDetached) {
      return;
    }
    final revision = _readerAloudNavigationRevision;
    final chapterIndex = position.chapterIndex.clamp(
      0,
      _loadedChapters.length - 1,
    );
    final chapter = _loadedChapters[chapterIndex];
    await chapter.loadTextAsync();
    if (!mounted ||
        revision != _readerAloudNavigationRevision ||
        (!force && _readerAloudNavigationDetached)) {
      return;
    }
    final offset = position.offset.clamp(0, chapter.plainText.length);
    if (_pageMode != NativePageMode.verticalScroll &&
        chapterIndex == _chapterIndex &&
        _visiblePages.isNotEmpty) {
      final first = _pageIndex.clamp(0, _visiblePages.length - 1);
      final last = (first + (_visibleUsesTwoPageLayout ? 1 : 0)).clamp(
        0,
        _visiblePages.length - 1,
      );
      if (offset >= _visiblePages[first].startOffset &&
          offset < _visiblePages[last].endOffset) {
        return;
      }
    }
    final excerptEnd = (offset + 72).clamp(offset, chapter.plainText.length);
    final locator = CanonicalLocator.fromComponents(
      format: BookFormat.fromFileExtension(widget.book.format),
      chapterId: chapter.id,
      offset: offset,
      excerpt: chapter.plainText.substring(offset, excerptEnd),
      progression: chapter.plainText.isEmpty
          ? 0
          : offset / chapter.plainText.length,
      contentSignature: _currentContentSignature,
    );
    await _jumpToBookmark(
      Bookmark(
        bookId: widget.book.id ?? 0,
        pageNumber: chapterIndex,
        chapterIndex: chapterIndex,
        chapterTitle: chapter.title,
        canonicalLocator: LocatorCodec.encodeCanonicalLocator(locator),
      ),
      _loadedChapters,
    );
  }

  Future<void> _persistReaderAloudPosition(ReaderAloudPosition position) async {
    final bookId = widget.book.id;
    if (bookId == null || _loadedChapters.isEmpty) return;
    _markReadingPositionChanged();
    final chapterIndex = position.chapterIndex.clamp(
      0,
      _loadedChapters.length - 1,
    );
    final chapter = _loadedChapters[chapterIndex];
    await chapter.loadTextAsync();
    final offset = position.offset.clamp(0, chapter.plainText.length);
    final excerptEnd = (offset + 72).clamp(offset, chapter.plainText.length);
    final locator = CanonicalLocator.fromComponents(
      format: BookFormat.fromFileExtension(widget.book.format),
      chapterId: chapter.id,
      offset: offset,
      excerpt: chapter.plainText.substring(offset, excerptEnd),
      progression: chapter.plainText.isEmpty
          ? 0
          : offset / chapter.plainText.length,
      contentSignature: _currentContentSignature,
    );
    final canonicalLocator = LocatorCodec.encodeCanonicalLocator(locator);
    unawaited(
      ReadingResumeService.recordPosition(
        bookId: bookId,
        canonicalLocator: canonicalLocator,
        chapterIndex: chapterIndex,
      ),
    );
    await _queuePositionWrite(
      () => BookDao().updateBookCanonicalLocator(
        bookId,
        canonicalLocator,
        null,
        _layoutSignature,
        chapterIndex,
        readingProgress:
            (chapterIndex +
                (chapter.plainText.isEmpty
                    ? 1.0
                    : offset / chapter.plainText.length)) /
            _loadedChapters.length,
      ),
    );
  }

  Future<void> _showReaderAloudPlayer() async {
    final controller = _ensureReaderAloudController();
    if (controller == null) return;
    final ttsService = context.read<TtsService>();
    final aloudService = context.read<ReaderAloudService>();
    await showReaderAloud(
      context: context,
      controller: controller,
      ttsService: ttsService,
      aloudService: aloudService,
      palette: _readerTheme,
      themeData: _readerThemeData,
      author: widget.book.author,
    );
  }

  /// Opens the preferred listening interface and starts playback if needed.
  Future<void> _handleReaderAloudButtonPressed() async {
    _pauseAutoPageTurn();
    await _showReaderAloudPlayer();
  }

  Future<ReaderFontChoice?> _showReaderFontPicker() async {
    final appSettings = context.read<AppSettingsNotifier>();
    await appSettings.prepareCustomFontPreviews();
    if (!mounted) return null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FontSelectionSheet(
        settings: appSettings,
        domain: _isEpub ? FontDomain.epubReader : FontDomain.reader,
        title: context.l10n.readerFont,
        description: context.l10n.readerFontSelectionDescription,
      ),
    );
    if (!mounted) return null;
    final selected = _isEpub
        ? appSettings.epubReaderFont
        : appSettings.readerFont;
    final profile = resolveReaderFontProfile(
      selection: selected,
      locale: Localizations.maybeLocaleOf(context),
    );
    return ReaderFontChoice(
      valueLabel: FontCatalog.labelFor(context.l10n, selected),
      hint: profile.preservesParsedFontFor(widget.book.format)
          ? context.l10n.readerFontBookPriorityHint
          : _isEpub
          ? context.l10n.readerFontOverrideHint
          : FontCatalog.descriptionFor(context.l10n, selected),
      family: profile.fontFamily,
      fallbackFamilies: profile.fontFamilyFallback,
      supportsVariableWeight: selected.supportsVariableWeight,
      fontWeightHint: selected.supportsVariableWeight
          ? context.l10n.readerFontWeightVariableHint(
              selected.variableWeightMin!,
              selected.variableWeightMax!,
            )
          : context.l10n.readerFontWeightSyntheticHint,
      variableWeightMin: selected.variableWeightMin,
      variableWeightMax: selected.variableWeightMax,
    );
  }

  Future<void> _showReadingSettings() async {
    _pauseAutoPageTurn();
    final selectedMode = await showModalBottomSheet<NativePageMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ReaderSettingsSheet(
        chapterProgressStyle: _chapterProgressStyle,
        onChapterProgressStyleChanged: (style) =>
            unawaited(_setChapterProgressStyle(style)),
        autoPageTurnController: _autoPageTurnController,
        autoPageTurnIsVertical: _pageMode == NativePageMode.verticalScroll,
        onAutoPageTurnSettings: () => unawaited(_showAutoPageTurnSettings()),
        title: context.l10n.readingSettings,
        tabThemeLabel: context.l10n.readerSettingsTabTheme,
        tabTextLabel: context.l10n.readerSettingsTabText,
        tabLayoutLabel: context.l10n.readerSettingsTabLayout,
        headerFooter: _headerFooter,
        headerFooterLabels: ReaderHeaderFooterLabels(
          tabLabel: context.l10n.readerSettingsTabHeaderFooter,
          headerSectionTitle: context.l10n.readerHeaderSectionTitle,
          headerEnabledTitle: context.l10n.readerHeaderEnabledTitle,
          headerEnabledHint: context.l10n.readerHeaderEnabledHint,
          headerChapterContent: context.l10n.readerHeaderChapterContent,
          headerBookContent: context.l10n.readerHeaderBookContent,
          headerTimeContent: context.l10n.readerHeaderTimeContent,
          headerBatteryContent: context.l10n.readerHeaderBatteryContent,
          headerPositionLabel: context.l10n.readerHeaderPositionLabel,
          headerFontSizeLabel: context.l10n.readerHeaderFontSizeLabel,
          headerTopBarHint: context.l10n.readerHeaderTopBarHint,
          footerSectionTitle: context.l10n.readerFooterSectionTitle,
          footerEnabledTitle: context.l10n.readerFooterEnabledTitle,
          footerEnabledHint: context.l10n.readerFooterEnabledHint,
          footerChapterContent: context.l10n.readerFooterChapterContent,
          footerPageContent: context.l10n.readerFooterPageContent,
          footerPercentContent: context.l10n.readerFooterPercentContent,
          footerRemainingContent: context.l10n.readerFooterRemainingContent,
          footerPositionLabel: context.l10n.readerFooterPositionLabel,
          footerFontSizeLabel: context.l10n.readerFooterFontSizeLabel,
          positionSplit: context.l10n.readerChromePositionSplit,
          positionLeft: context.l10n.readerChromePositionLeft,
          positionCenter: context.l10n.readerChromePositionCenter,
          positionRight: context.l10n.readerChromePositionRight,
        ),
        headerFooterHint: _pageMode == NativePageMode.verticalScroll
            ? context.l10n.readerHeaderFooterScrollHint
            : null,
        doneLabel: context.l10n.readerHeaderFooterDone,
        onHeaderFooterChanged: (value) => unawaited(_setHeaderFooter(value)),
        advancedTypographyTitle: context.l10n.readerSettingsAdvancedTypography,
        themeDescription: context.l10n.readerThemeDescription,
        pageModeTitle: context.l10n.pageTurningMode,
        pageModeSummary: _pageModeSummary(context),
        topBarStyleTitle: context.l10n.readerTopBarStyleTitle,
        topBarStyleSummary: _topBarStyleTitle(_topBarStyle),
        pullBookmarkTitle: context.l10n.readerPullBookmarkTitle,
        pullBookmarkHint: context.l10n.readerPullBookmarkHint,
        tapPageAnimationTitle: context.l10n.readerTapAnimationTitle,
        tapPageAnimationHint: context.l10n.readerTapAnimationHint,
        tapZonesTitle: context.l10n.tapZoneSettings,
        tapZonesHint: context.l10n.tapZoneSettingsHint,
        showTabletTwoPageToggle: ReaderLayoutBreakpoints.isTablet(
          MediaQuery.sizeOf(context),
        ),
        tabletTwoPageTitle: context.l10n.readerTabletTwoPageTitle,
        tabletTwoPageHint: context.l10n.readerTabletTwoPageHint,
        fontFamilyLabel: context.l10n.fontFamilyLabel,
        fontFamilyValueLabel: FontCatalog.labelFor(context.l10n, _readerFont),
        fontFamilyHint: _preserveDocumentFont
            ? context.l10n.readerFontBookPriorityHint
            : _isEpub
            ? context.l10n.readerFontOverrideHint
            : FontCatalog.descriptionFor(context.l10n, _readerFont),
        onFontFamilyTap: _showReaderFontPicker,
        onRestoreDesignDefaults: _restoreDesignDefaults,
        fontSizeLabel: context.l10n.fontSizeLabel,
        textBrightnessLabel: context.l10n.readerTextBrightnessLabel,
        dimTextInDarkModeTitle: context.l10n.readerDimTextInDarkModeTitle,
        dimTextInDarkModeHint: context.l10n.readerDimTextInDarkModeHint,
        fontWeightLabel: context.l10n.readerFontWeightLabel,
        fontWeightValueLabels: <String>[
          context.l10n.readerFontWeightLight,
          context.l10n.readerFontWeightRegular,
          context.l10n.readerFontWeightMedium,
          context.l10n.readerFontWeightSemiBold,
          context.l10n.readerFontWeightBold,
        ],
        fontWeightHint: _readerFont.supportsVariableWeight
            ? context.l10n.readerFontWeightVariableHint(
                _readerFont.variableWeightMin!,
                _readerFont.variableWeightMax!,
              )
            : context.l10n.readerFontWeightSyntheticHint,
        fontWeightPreviewText: context.l10n.readerFontWeightPreview,
        lineHeightLabel: context.l10n.lineSpacingLabel,
        letterSpacingLabel: context.l10n.letterSpacingLabel,
        textAlignmentLabel: context.l10n.textAlignmentLabel,
        textAlignmentNaturalLabel: context.l10n.textAlignmentNatural,
        textAlignmentJustifiedLabel: context.l10n.textAlignmentJustified,
        firstLineIndentLabel: context.l10n.firstLineIndentLabel,
        paragraphSpacingLabel: context.l10n.paragraphSpacingLabel,
        horizontalMarginLabel: context.l10n.readerHorizontalMarginLabel,
        topMarginLabel: context.l10n.readerTopMarginLabel,
        bottomMarginLabel: context.l10n.readerBottomMarginLabel,
        chapterTitlePageTitle: context.l10n.readerTxtChapterTitlePageTitle,
        chapterTitlePageHint: context.l10n.readerTxtChapterTitlePageHint,
        showChapterTitlePageToggle: widget.book.format.toLowerCase() == 'txt',
        themeId: _readerThemeId,
        fontSize: _fontSize,
        textBrightness: _textBrightness,
        dimTextInDarkMode: _dimTextInDarkMode,
        fontWeight: _fontWeight,
        fontFamily: _readerFontProfile.fontFamily,
        fontFamilyFallback: _readerFontProfile.fontFamilyFallback,
        fontWeightSupportsVariable: _readerFont.supportsVariableWeight,
        fontWeightVariableMin: _readerFont.variableWeightMin,
        fontWeightVariableMax: _readerFont.variableWeightMax,
        lineHeight: _lineHeight,
        letterSpacing: _letterSpacing,
        textAlignment: _textAlignment,
        firstLineIndent: _firstLineIndent,
        paragraphSpacing: _paragraphSpacing,
        horizontalMargin: _horizontalMargin,
        topMargin: _topMargin,
        bottomMargin: _bottomMargin,
        pullBookmarkEnabled: _pullBookmarkEnabled,
        tapPageAnimationEnabled: _tapPageAnimationEnabled,
        tabletTwoPageEnabled: _tabletTwoPageEnabled,
        chapterTitlePageEnabled: _chapterTitlePageEnabled,
        themeLabelFor: (id) => _readerThemeName(context, id),
        onThemeChanged: (id) => unawaited(_setReaderTheme(id)),
        onThemeConfigChanged: () => unawaited(_refreshReaderThemePalette()),
        onCustomThemeTap: _showCustomThemeEditor,
        onPageModeTap: _showPageModeSettings,
        onTopBarStyleTap: _showTopBarStyleSettings,
        onTapZonesTap: () => unawaited(_showTapZoneSettings()),
        onFontSizeChanged: (value) => unawaited(_updateLayout(fontSize: value)),
        onTextBrightnessChanged: (value) =>
            unawaited(_updateLayout(textBrightness: value)),
        onDimTextInDarkModeChanged: (value) =>
            unawaited(_updateLayout(dimTextInDarkMode: value)),
        onFontWeightChanged: (value) =>
            unawaited(_updateLayout(fontWeight: value)),
        onLineHeightChanged: (value) =>
            unawaited(_updateLayout(lineHeight: value)),
        onLetterSpacingChanged: (value) =>
            unawaited(_updateLayout(letterSpacing: value)),
        onTextAlignmentChanged: (value) =>
            unawaited(_updateLayout(textAlignment: value)),
        onFirstLineIndentChanged: (value) =>
            unawaited(_updateLayout(firstLineIndent: value)),
        onParagraphSpacingChanged: (value) =>
            unawaited(_updateLayout(paragraphSpacing: value)),
        onHorizontalMarginChanged: (value) =>
            unawaited(_updateLayout(horizontalMargin: value)),
        onTopMarginChanged: (value) =>
            unawaited(_updateLayout(topMargin: value)),
        onBottomMarginChanged: (value) =>
            unawaited(_updateLayout(bottomMargin: value)),
        onPullBookmarkChanged: (value) =>
            unawaited(_setInteractionPreferences(pullBookmark: value)),
        onTapPageAnimationChanged: (value) =>
            unawaited(_setInteractionPreferences(tapAnimation: value)),
        onTabletTwoPageChanged: (value) =>
            unawaited(_setTabletTwoPageEnabled(value)),
        onChapterTitlePageChanged: (value) =>
            unawaited(_setChapterTitlePageEnabled(value)),
      ),
    );
    if (!mounted) return;
    await _applyReaderSystemUi();
    if (selectedMode == null || !mounted) return;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _setPageMode(selectedMode);
  }

  Future<void> _setInteractionPreferences({
    bool? pullBookmark,
    bool? tapAnimation,
  }) async {
    _setReaderState(() {
      _pullBookmarkEnabled = pullBookmark ?? _pullBookmarkEnabled;
      _tapPageAnimationEnabled = tapAnimation ?? _tapPageAnimationEnabled;
    });
    await _readerSettingsStore.save(_readerSettings);
  }

  Future<void> _setTabletTwoPageEnabled(bool value) async {
    if (_tabletTwoPageEnabled == value) return;
    _setReaderState(() {
      _tabletTwoPageEnabled = value;
      _restoreAnchorAfterLayout = true;
      _lastSavedLocation = null;
    });
    await _readerSettingsStore.save(_readerSettings);
  }

  Future<void> _showCustomThemeEditor() async {
    Navigator.of(context).pop();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final result = await Navigator.of(context).push<ReaderCustomThemesResult>(
      MaterialPageRoute(
        builder: (_) => ReaderCustomThemesPage(
          initialThemes: ReaderThemes.customThemes,
          initialThemeOrder: ReaderThemes.themeOrder,
          initialSelectedThemeId: _readerThemeId,
        ),
      ),
    );
    if (result == null || !mounted) return;
    ReaderThemes.setCustomThemes(result.themes);
    ReaderThemes.setThemeOrder(result.themeOrder);
    _setReaderState(() {
      if (result.selectedThemeId != null) {
        _readerThemeId = result.selectedThemeId!;
      } else if (ReaderCustomTheme.isCustomThemeId(_readerThemeId) &&
          ReaderThemes.customThemeById(_readerThemeId) == null) {
        _readerThemeId = ReaderSettings.defaultThemeId;
      }
    });
    ReaderThemes.rememberSavedPalette(_readerTheme);
    await _readerSettingsStore.save(_readerSettings);
    await _applyReaderSystemUi();
  }

  /// 底部进度滑杆：把本章 0..1 进度落到具体页，并在可用时同步横向 PageView。
  void _seekToChapterPage(
    double value,
    List<_ReaderPageData> pages,
    List<_BookPageRef> bookPages,
    List<_NativeChapter> chapters,
  ) {
    if (pages.isEmpty) return;
    final progress = value.clamp(0.0, 1.0);
    final keepChromeVisible = _controlsVisible;
    if (_pageMode == NativePageMode.verticalScroll) {
      final parts = _visibleContinuousParts;
      if (parts.length > 1 &&
          _usesChapterScopedVerticalList &&
          _verticalPageScrollController.isAttached) {
        final target = (progress * (parts.length - 1)).round();
        unawaited(
          _verticalPageScrollController.scrollTo(
            index: target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          ),
        );
      }
      _verticalScrollProgress.value = progress;
      _markReadingPositionChanged();
      _keepChromeAfterSeek(keepChromeVisible);
      return;
    }
    final lastIndex = pages.length - 1;
    var targetPage = (progress * lastIndex).round().clamp(0, lastIndex);
    if (_visibleUsesTwoPageLayout) {
      targetPage = _spreadStartForPage(targetPage);
    }
    final usesBookPages =
        bookPages.isNotEmpty && _pageMode != NativePageMode.instantPage;
    if (usesBookPages) {
      final bookIndex = bookPages.indexWhere(
        (page) =>
            page.chapterIndex == _chapterIndex && page.pageIndex == targetPage,
      );
      if (bookIndex >= 0) {
        if (_pageMode == NativePageMode.horizontalSlide) {
          final controller = _pageController;
          if (controller != null && controller.hasClients) {
            final localIndex = _visibleUsesTwoPageLayout
                ? bookIndex ~/ 2
                : bookIndex;
            controller.jumpToPage(_horizontalPageIndexMap.origin + localIndex);
          }
        }
        _onBookPageChanged(bookIndex, bookPages, chapters);
        _keepChromeAfterSeek(keepChromeVisible);
        return;
      }
    }
    _markReaderAloudForManualPageTurn();
    _setReaderState(() => _pageIndex = targetPage);
    _keepChromeAfterSeek(keepChromeVisible);
  }

  /// 跳页会把控制栏按「翻页」逻辑收起；滑杆操作期间需要把它留在屏幕上。
  void _keepChromeAfterSeek(bool wasVisible) {
    if (!wasVisible) return;
    _controlsTimer?.cancel();
    if (!_controlsVisible) _setReaderState(() => _controlsVisible = true);
    _controlsTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _setReaderState(() => _controlsVisible = false);
    });
  }

  Future<void> _showReaderMoreMenu() async {
    final palette = _readerTheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.surface,
      showDragHandle: true,
      builder: (menuContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                context.l10n.readerMoreActions,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
            _ReaderMoreTile(
              palette: palette,
              icon: Icons.search_rounded,
              label: context.l10n.search,
              onTap: () => Navigator.of(menuContext).pop('search'),
            ),
            _ReaderMoreTile(
              palette: palette,
              icon: Icons.auto_stories_rounded,
              label: context.l10n.pageTurningMode,
              onTap: () => Navigator.of(menuContext).pop('pageMode'),
            ),
            _ReaderMoreTile(
              palette: palette,
              icon: Icons.av_timer_rounded,
              label: context.l10n.readerAutoPageTurnTitle,
              onTap: () => Navigator.of(menuContext).pop('autoPageTurn'),
            ),
            _ReaderMoreTile(
              palette: palette,
              icon: Icons.settings_backup_restore_rounded,
              label: context.l10n.readerRestoreDesignDefaults,
              onTap: () => Navigator.of(menuContext).pop('restore'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'search':
        await _showFullTextSearch();
      case 'pageMode':
        await _showPageModePicker();
      case 'autoPageTurn':
        await _showAutoPageTurnPicker();
      case 'restore':
        await _confirmRestoreDesignDefaults();
    }
  }

  Future<void> _showPageModePicker() async {
    final selectedMode = await _pickPageMode();
    if (selectedMode == null || !mounted) return;
    await _setPageMode(selectedMode);
  }

  Future<void> _showAutoPageTurnPicker() async {
    _pauseAutoPageTurn();
    final selection = await showReaderAutoPageTurnSheet(
      context: context,
      palette: _readerTheme,
      controller: _autoPageTurnController,
      vertical: _pageMode == NativePageMode.verticalScroll,
    );
    if (selection == null || !_canAutoPageTurn) return;
    await _autoPageTurnController.applySelection(selection);
    if (_canAutoPageTurn) await _resumeAutoPageTurn();
  }

  Future<void> _confirmRestoreDesignDefaults() async {
    final palette = _readerTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          context.l10n.readerRestoreDesignDefaults,
          style: TextStyle(fontSize: 16, color: palette.text),
        ),
        content: Text(
          context.l10n.readerRestoreDesignDefaultsConfirm,
          style: TextStyle(fontSize: 13, height: 1.5, color: palette.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _restoreDesignDefaults();
  }

  Future<void> _restoreDesignDefaults() async {
    final appSettings = context.read<AppSettingsNotifier>();
    await ReaderDesignMigration.applyDesignDefaults();
    await appSettings.setReaderFontId(FontCatalog.serifFont.id);
    if (!mounted) return;
    await _loadPageMode();
    if (!mounted) return;
    showSideToast(context, context.l10n.readerRestoreDesignDefaultsDone);
  }

  String _pageModeSummary(BuildContext context) {
    switch (_pageMode) {
      case NativePageMode.verticalScroll:
        return _scrollByChapter
            ? context.l10n.readerModeVerticalScrollHint
            : context.l10n.readerModeWholeBookScrollHint;
      case NativePageMode.instantPage:
        return context.l10n.readerModeHorizontalPageHint;
      case NativePageMode.horizontalSlide:
        return context.l10n.readerModeHorizontalSlideHint;
      case NativePageMode.coverSlide:
        return context.l10n.readerModeCoverSlideHint;
      case NativePageMode.pageCurl:
        return context.l10n.readerModePageCurlHint;
    }
  }

  Future<void> _showPageModeSettings() async {
    final selectedMode = await _pickPageMode();
    if (selectedMode == null || !mounted) return;
    Navigator.of(context).pop(selectedMode);
  }

  Future<NativePageMode?> _pickPageMode() async {
    var previewScrollByChapter = _scrollByChapter;
    return showModalBottomSheet<NativePageMode>(
      context: context,
      backgroundColor: _readerTheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (menuContext) => StatefulBuilder(
        builder: (context, setMenuState) => ReaderPageModeSheet(
          palette: _readerTheme,
          title: context.l10n.pageTurningMode,
          selectedMode: _pageMode,
          titleFor: _pageModeTitle,
          hintFor: (mode) => mode == NativePageMode.verticalScroll
              ? (previewScrollByChapter
                    ? context.l10n.readerModeVerticalScrollHint
                    : context.l10n.readerModeWholeBookScrollHint)
              : _pageModeHint(mode),
          onSelected: (mode) => Navigator.of(menuContext).pop(mode),
          scrollByChapter: previewScrollByChapter,
          scrollByChapterTitle: context.l10n.readerScrollByChapterTitle,
          scrollByChapterOnHint: context.l10n.readerScrollByChapterOnHint,
          scrollByChapterOffHint: context.l10n.readerScrollByChapterOffHint,
          onScrollByChapterChanged: (value) {
            setMenuState(() => previewScrollByChapter = value);
            unawaited(_setScrollByChapter(value));
          },
        ),
      ),
    );
  }

  Future<void> _showTopBarStyleSettings() async {
    final selectedStyle = await showModalBottomSheet<ReaderTopBarStyle>(
      context: context,
      backgroundColor: _readerTheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (menuContext) => ReaderTopBarStyleSheet(
        palette: _readerTheme,
        title: context.l10n.readerTopBarStyleTitle,
        selectedStyle: _topBarStyle,
        titleFor: _topBarStyleTitle,
        hintFor: _topBarStyleHint,
        onSelected: (style) => Navigator.of(menuContext).pop(style),
      ),
    );
    if (selectedStyle == null || !mounted) return;
    Navigator.of(context).pop();
    await _setTopBarStyle(selectedStyle);
  }

  String _pageModeTitle(NativePageMode mode) => switch (mode) {
    NativePageMode.verticalScroll => context.l10n.pageTurningScroll,
    NativePageMode.instantPage => context.l10n.readerModeHorizontalPage,
    NativePageMode.horizontalSlide => context.l10n.pageTurningSlide,
    NativePageMode.coverSlide => context.l10n.readerModeCoverSlide,
    NativePageMode.pageCurl => context.l10n.readerModePageCurl,
  };

  String _pageModeHint(NativePageMode mode) => switch (mode) {
    NativePageMode.verticalScroll => context.l10n.readerModeVerticalScrollHint,
    NativePageMode.instantPage => context.l10n.readerModeHorizontalPageHint,
    NativePageMode.horizontalSlide =>
      context.l10n.readerModeHorizontalSlideHint,
    NativePageMode.coverSlide => context.l10n.readerModeCoverSlideHint,
    NativePageMode.pageCurl => context.l10n.readerModePageCurlHint,
  };

  String _topBarStyleTitle(ReaderTopBarStyle style) => switch (style) {
    ReaderTopBarStyle.system => context.l10n.readerTopBarStyleSystem,
    ReaderTopBarStyle.reader => context.l10n.readerTopBarStyleReader,
    ReaderTopBarStyle.floating => context.l10n.readerTopBarStyleFloating,
    ReaderTopBarStyle.hidden => context.l10n.readerTopBarStyleHidden,
  };

  String _topBarStyleHint(ReaderTopBarStyle style) => switch (style) {
    ReaderTopBarStyle.system => context.l10n.readerTopBarStyleSystemHint,
    ReaderTopBarStyle.reader => context.l10n.readerTopBarStyleReaderHint,
    ReaderTopBarStyle.floating => context.l10n.readerTopBarStyleFloatingHint,
    ReaderTopBarStyle.hidden => context.l10n.readerTopBarStyleHiddenHint,
  };
}

class _ReaderMoreTile extends StatelessWidget {
  const _ReaderMoreTile({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ReaderThemePalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 19, color: palette.text),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: palette.text),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
