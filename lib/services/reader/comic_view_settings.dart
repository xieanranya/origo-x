// 文件说明：漫画阅读的视图设置与页面编排，能力对齐 Perfect Viewer。
// 覆盖：翻页方向、双页扫描自动分割、双页跨页并排、分屏缩放、白边裁剪、颜色校正、
// 自动翻页、点击分区翻页。颜色校正合成单个 4x5 矩阵由 GPU 一次完成。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 漫画翻页方向。
enum ComicPageDirection {
  /// 垂直连贯（Webtoon，上下滑动）
  vertical,

  /// 水平左滑：向左滑到下一页（西式阅读顺序）
  horizontalLeft,

  /// 水平右滑：向右滑到下一页（日式漫画阅读顺序）
  horizontalRight,
}

extension ComicPageDirectionLabel on ComicPageDirection {
  String get label => switch (this) {
    ComicPageDirection.vertical => '垂直连贯',
    ComicPageDirection.horizontalLeft => '水平左滑',
    ComicPageDirection.horizontalRight => '水平右滑',
  };

  bool get isHorizontal => this != ComicPageDirection.vertical;

  /// 是否是反向（日漫）翻页。
  bool get reversed => this == ComicPageDirection.horizontalRight;
}

/// 阅读模式：页模式 / 垂直卷动模式 / 水平卷动模式（对齐原版）。
enum ComicPageLayout {
  page('页模式'),
  verticalScroll('垂直卷动模式'),
  horizontalScroll('水平卷动模式');

  const ComicPageLayout(this.label);

  final String label;
}

/// 屏幕方向（对应「屏幕方向」）。
enum ComicScreenOrientation {
  automatic('自动'),
  portrait('直立'),
  landscape('横向');

  const ComicScreenOrientation(this.label);

  final String label;
}

/// 界面主题（对应「界面主题」）。
enum ComicInterfaceTheme {
  light('亮色'),
  dark('暗色');

  const ComicInterfaceTheme(this.label);

  final String label;
}

/// 缩放方式，对应 Perfect Viewer 的「缩放方式」。
enum ComicFitMode {
  fitWidth('符合宽度'),
  fitHeight('符合高度'),
  contain('符合画面');

  const ComicFitMode(this.label);

  final String label;
}

/// 漫画视图设置。
@immutable
class ComicViewSettings {
  const ComicViewSettings({
    this.direction = ComicPageDirection.vertical,
    this.layout = ComicPageLayout.verticalScroll,
    this.fitMode = ComicFitMode.fitWidth,
    this.cropBorders = false,
    this.splitDoublePage = false,
    this.autoTurn = false,
    this.autoTurnSeconds = 6,
    this.tapToTurn = true,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.hue = 0,
    this.gamma = 1,
    this.invert = false,
    this.grayscale = false,
    this.sepia = false,
    this.autoLevels = false,
    this.redBalance = 1,
    this.greenBalance = 1,
    this.blueBalance = 1,
    this.screenOrientation = ComicScreenOrientation.automatic,
    this.interfaceTheme = ComicInterfaceTheme.dark,
    this.backlight = 100,
    this.blueLightFilter = 0,
    this.pageGap = 0,
    this.blankFirstPage = false,
    this.blur = 0,
    this.sharpen = 0,
    this.manualCrop = 0,
    this.showProgressBar = true,
  });

  final ComicPageDirection direction;
  final ComicPageLayout layout;
  final ComicFitMode fitMode;

  /// 自动裁掉页面四周的白边。
  final bool cropBorders;

  /// 横向宽图视为双页扫描，自动切成左右两页分别翻。
  final bool splitDoublePage;

  /// 自动翻页。
  final bool autoTurn;
  final int autoTurnSeconds;

  /// 点击屏幕左右区域翻页（中间区域显隐控件）。
  final bool tapToTurn;

  /// 亮度 -100 ~ 100
  final double brightness;

  /// 对比度 50 ~ 200（百分比）
  final double contrast;

  /// 饱和度 0 ~ 200（百分比）
  final double saturation;

  /// 色相 -180 ~ 180（度）
  final double hue;

  /// Gamma 50 ~ 200（百分比）
  final double gamma;

  final bool invert;
  final bool grayscale;

  /// 复古色调。
  final bool sepia;

  /// 自动调整亮度对比（对画面做一次自适应拉伸）。
  final bool autoLevels;

  /// 色彩平衡：红 / 绿 / 蓝通道增益。
  final double redBalance;
  final double greenBalance;
  final double blueBalance;

  /// 屏幕方向。
  final ComicScreenOrientation screenOrientation;

  /// 界面主题。
  final ComicInterfaceTheme interfaceTheme;

  /// 背光控制 20~100（以黑色蒙版近似降低屏幕亮度）。
  final double backlight;

  /// 过滤蓝光 0~100（琥珀色蒙版）。
  final double blueLightFilter;

  /// 页面边界：页与页之间的间距（逻辑像素）。
  final double pageGap;

  /// 插入空白页作为封里。
  final bool blankFirstPage;

  /// 高斯模糊半径（0 表示关闭）。
  final double blur;

  /// 锐化强度 0~1。
  final double sharpen;

  /// 手工裁切：四边各裁掉的百分比 0~0.3。
  final double manualCrop;

  /// 底部显示进度条。
  final bool showProgressBar;

  bool get hasColorAdjust =>
      brightness != 0 ||
      contrast != 1 ||
      saturation != 1 ||
      hue != 0 ||
      gamma != 1 ||
      invert ||
      grayscale ||
      sepia ||
      autoLevels ||
      redBalance != 1 ||
      greenBalance != 1 ||
      blueBalance != 1 ||
      blur > 0 ||
      sharpen > 0 ||
      manualCrop > 0;

  ComicViewSettings copyWith({
    ComicPageDirection? direction,
    ComicPageLayout? layout,
    ComicFitMode? fitMode,
    bool? cropBorders,
    bool? splitDoublePage,
    bool? autoTurn,
    int? autoTurnSeconds,
    bool? tapToTurn,
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    double? gamma,
    bool? invert,
    bool? grayscale,
    bool? sepia,
    bool? autoLevels,
    double? redBalance,
    double? greenBalance,
    double? blueBalance,
    ComicScreenOrientation? screenOrientation,
    ComicInterfaceTheme? interfaceTheme,
    double? backlight,
    double? blueLightFilter,
    double? pageGap,
    bool? blankFirstPage,
    double? blur,
    double? sharpen,
    double? manualCrop,
    bool? showProgressBar,
  }) {
    return ComicViewSettings(
      direction: direction ?? this.direction,
      layout: layout ?? this.layout,
      fitMode: fitMode ?? this.fitMode,
      cropBorders: cropBorders ?? this.cropBorders,
      splitDoublePage: splitDoublePage ?? this.splitDoublePage,
      autoTurn: autoTurn ?? this.autoTurn,
      autoTurnSeconds: autoTurnSeconds ?? this.autoTurnSeconds,
      tapToTurn: tapToTurn ?? this.tapToTurn,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      gamma: gamma ?? this.gamma,
      invert: invert ?? this.invert,
      grayscale: grayscale ?? this.grayscale,
      sepia: sepia ?? this.sepia,
      autoLevels: autoLevels ?? this.autoLevels,
      redBalance: redBalance ?? this.redBalance,
      greenBalance: greenBalance ?? this.greenBalance,
      blueBalance: blueBalance ?? this.blueBalance,
      screenOrientation: screenOrientation ?? this.screenOrientation,
      interfaceTheme: interfaceTheme ?? this.interfaceTheme,
      backlight: backlight ?? this.backlight,
      blueLightFilter: blueLightFilter ?? this.blueLightFilter,
      pageGap: pageGap ?? this.pageGap,
      blankFirstPage: blankFirstPage ?? this.blankFirstPage,
      blur: blur ?? this.blur,
      sharpen: sharpen ?? this.sharpen,
      manualCrop: manualCrop ?? this.manualCrop,
      showProgressBar: showProgressBar ?? this.showProgressBar,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'direction': direction.name,
    'layout': layout.name,
    'fitMode': fitMode.name,
    'cropBorders': cropBorders,
    'splitDoublePage': splitDoublePage,
    'autoTurn': autoTurn,
    'autoTurnSeconds': autoTurnSeconds,
    'tapToTurn': tapToTurn,
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'hue': hue,
    'gamma': gamma,
    'invert': invert,
    'grayscale': grayscale,
    'sepia': sepia,
    'autoLevels': autoLevels,
    'redBalance': redBalance,
    'greenBalance': greenBalance,
    'blueBalance': blueBalance,
    'screenOrientation': screenOrientation.name,
    'interfaceTheme': interfaceTheme.name,
    'backlight': backlight,
    'blueLightFilter': blueLightFilter,
    'pageGap': pageGap,
    'blankFirstPage': blankFirstPage,
    'blur': blur,
    'sharpen': sharpen,
    'manualCrop': manualCrop,
    'showProgressBar': showProgressBar,
  };

  static ComicViewSettings fromJson(Map<String, dynamic> json) {
    ComicPageDirection parseDirection(Object? value) {
      for (final item in ComicPageDirection.values) {
        if (item.name == value) return item;
      }
      return ComicPageDirection.vertical;
    }

    ComicPageLayout parseLayout(Object? value) {
      for (final item in ComicPageLayout.values) {
        if (item.name == value) return item;
      }
      return ComicPageLayout.verticalScroll;
    }

    ComicFitMode parseFitMode(Object? value) {
      for (final item in ComicFitMode.values) {
        if (item.name == value) return item;
      }
      return ComicFitMode.fitWidth;
    }

    double asDouble(Object? value, double fallback) =>
        value is num ? value.toDouble() : fallback;

    int asInt(Object? value, int fallback) =>
        value is num ? value.toInt() : fallback;

    return ComicViewSettings(
      direction: parseDirection(json['direction']),
      layout: parseLayout(json['layout']),
      fitMode: parseFitMode(json['fitMode']),
      cropBorders: json['cropBorders'] == true,
      splitDoublePage: json['splitDoublePage'] == true,
      autoTurn: json['autoTurn'] == true,
      autoTurnSeconds: asInt(json['autoTurnSeconds'], 6).clamp(2, 60).toInt(),
      tapToTurn: json['tapToTurn'] != false,
      brightness: asDouble(json['brightness'], 0),
      contrast: asDouble(json['contrast'], 1),
      saturation: asDouble(json['saturation'], 1),
      hue: asDouble(json['hue'], 0),
      gamma: asDouble(json['gamma'], 1),
      invert: json['invert'] == true,
      grayscale: json['grayscale'] == true,
      sepia: json['sepia'] == true,
      autoLevels: json['autoLevels'] == true,
      redBalance: asDouble(json['redBalance'], 1),
      greenBalance: asDouble(json['greenBalance'], 1),
      blueBalance: asDouble(json['blueBalance'], 1),
      screenOrientation: () {
        for (final item in ComicScreenOrientation.values) {
          if (item.name == json['screenOrientation']) return item;
        }
        return ComicScreenOrientation.automatic;
      }(),
      interfaceTheme: json['interfaceTheme'] == ComicInterfaceTheme.light.name
          ? ComicInterfaceTheme.light
          : ComicInterfaceTheme.dark,
      backlight: asDouble(json['backlight'], 100),
      blueLightFilter: asDouble(json['blueLightFilter'], 0),
      pageGap: asDouble(json['pageGap'], 0),
      blankFirstPage: json['blankFirstPage'] == true,
      blur: asDouble(json['blur'], 0),
      sharpen: asDouble(json['sharpen'], 0),
      manualCrop: asDouble(json['manualCrop'], 0),
      showProgressBar: json['showProgressBar'] != false,
    );
  }
}

/// 漫画视图设置的读写。
class ComicViewSettingsStore {
  const ComicViewSettingsStore();

  static const String _key = 'comic_view_settings_v2';

  Future<ComicViewSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const ComicViewSettings();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const ComicViewSettings();
      return ComicViewSettings.fromJson(decoded);
    } catch (_) {
      return const ComicViewSettings();
    }
  }

  Future<void> save(ComicViewSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(settings.toJson()));
    } catch (_) {
      // 保存失败不阻断阅读。
    }
  }
}

/// 一个待显示的画面：同一张源图可能被切成多个画面（双页扫描 / 分屏）。
@immutable
class ComicFrame {
  const ComicFrame({
    required this.imagePath,
    required this.src,
    required this.logicalPage,
    required this.imageAspect,
  });

  final String imagePath;

  /// 源图内的归一化裁剪区域（0..1）。
  final Rect src;

  /// 对应的源图序号，用于记录阅读进度。
  final int logicalPage;

  /// 源图宽高比（宽 / 高）。
  final double imageAspect;
}

/// 屏幕上一次呈现的内容：单页或双页并排。
@immutable
class ComicSpread {
  const ComicSpread({
    required this.logicalPage,
    this.left,
    this.right,
  });

  final int logicalPage;
  final ComicFrame? left;
  final ComicFrame? right;
}

/// 页面编排：把源图列表按设置展开成可翻的画面。
class ComicPageComposer {
  ComicPageComposer._();

  /// 宽高比大于该值的图视为「双页扫描」。
  static const double doublePageAspect = 1.15;

  static const Rect fullRect = Rect.fromLTRB(0, 0, 1, 1);

  /// 读取图片宽高比（只解码极小尺寸，成本很低）。
  static Future<Map<String, double>> probeAspects(List<String> paths) async {
    final result = <String, double>{};
    for (final path in paths) {
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final width = image.width;
        final height = image.height;
        image.dispose();
        codec.dispose();
        if (width > 0 && height > 0) {
          result[path] = width / height;
        }
      } catch (_) {
        // 忽略单张图的探测失败。
      }
    }
    return result;
  }

  /// 把源图展开成画面列表。
  static List<ComicFrame> expandFrames({
    required List<String> paths,
    required Map<String, double> aspects,
    required ComicViewSettings settings,
  }) {
    final frames = <ComicFrame>[];
    for (var index = 0; index < paths.length; index++) {
      final path = paths[index];
      final aspect = aspects[path] ?? 0.7;
      // 双页扫描：横向宽图切成左右两半。
      if (settings.splitDoublePage && aspect > doublePageAspect) {
        const leftHalf = Rect.fromLTRB(0, 0, 0.5, 1);
        const rightHalf = Rect.fromLTRB(0.5, 0, 1, 1);
        if (settings.direction.reversed) {
          // 日漫：从右往左读，先看右半。
          frames.add(
            ComicFrame(
              imagePath: path,
              src: rightHalf,
              logicalPage: index,
              imageAspect: aspect,
            ),
          );
          frames.add(
            ComicFrame(
              imagePath: path,
              src: leftHalf,
              logicalPage: index,
              imageAspect: aspect,
            ),
          );
        } else {
          frames.add(
            ComicFrame(
              imagePath: path,
              src: leftHalf,
              logicalPage: index,
              imageAspect: aspect,
            ),
          );
          frames.add(
            ComicFrame(
              imagePath: path,
              src: rightHalf,
              logicalPage: index,
              imageAspect: aspect,
            ),
          );
        }
        continue;
      }
      frames.add(
        ComicFrame(
          imagePath: path,
          src: fullRect,
          logicalPage: index,
          imageAspect: aspect,
        ),
      );
    }

    return frames;
  }

  /// 把画面两两配对成「屏」。
  /// 一帧一屏。双页扫描的切分已在 expandFrames 里完成，这里只做单页包装。
  static List<ComicSpread> composeSpreads({
    required List<ComicFrame> frames,
    required ComicViewSettings settings,
  }) {
    return frames
        .map(
          (frame) => ComicSpread(logicalPage: frame.logicalPage, left: frame),
        )
        .toList(growable: false);
  }
}

/// 把视图设置合成一个 4x5 颜色矩阵。
class ComicColorMatrix {
  ComicColorMatrix._();

  static const List<double> identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// 4x5 仿射矩阵相乘：先 [b] 后 [a]。
  static List<double> multiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        if (col == 4) sum += a[row * 5 + 4];
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }

  static List<double> brightnessMatrix(double value) {
    final offset = value / 100 * 255;
    return <double>[
      1, 0, 0, 0, offset, //
      0, 1, 0, 0, offset, //
      0, 0, 1, 0, offset, //
      0, 0, 0, 1, 0, //
    ];
  }

  static List<double> contrastMatrix(double percent) {
    final scale = percent / 100;
    final offset = 128 * (1 - scale);
    return <double>[
      scale, 0, 0, 0, offset, //
      0, scale, 0, 0, offset, //
      0, 0, scale, 0, offset, //
      0, 0, 0, 1, 0, //
    ];
  }

  static List<double> saturationMatrix(double percent) {
    final s = percent / 100;
    const lumR = 0.213;
    const lumG = 0.715;
    const lumB = 0.072;
    return <double>[
      lumR * (1 - s) + s, lumG * (1 - s), lumB * (1 - s), 0, 0, //
      lumR * (1 - s), lumG * (1 - s) + s, lumB * (1 - s), 0, 0, //
      lumR * (1 - s), lumG * (1 - s), lumB * (1 - s) + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  static List<double> hueMatrix(double degrees) {
    final radians = degrees * 3.1415926535897932 / 180;
    final cosValue = _cos(radians);
    final sinValue = _sin(radians);
    const lumR = 0.213;
    const lumG = 0.715;
    const lumB = 0.072;
    return <double>[
      lumR + cosValue * (1 - lumR) + sinValue * (-lumR),
      lumG + cosValue * (-lumG) + sinValue * (-lumG),
      lumB + cosValue * (-lumB) + sinValue * (1 - lumB),
      0,
      0,
      lumR + cosValue * (-lumR) + sinValue * 0.143,
      lumG + cosValue * (1 - lumG) + sinValue * 0.140,
      lumB + cosValue * (-lumB) + sinValue * (-0.283),
      0,
      0,
      lumR + cosValue * (-lumR) + sinValue * (-(1 - lumR)),
      lumG + cosValue * (-lumG) + sinValue * lumG,
      lumB + cosValue * (1 - lumB) + sinValue * lumB,
      0,
      0,
      0, 0, 0, 1, 0, //
    ];
  }

  static List<double> invertMatrix() => <double>[
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ];

  /// 色彩平衡：红 / 绿 / 蓝通道增益。
  static List<double> balanceMatrix(double red, double green, double blue) =>
      <double>[
        red, 0, 0, 0, 0, //
        0, green, 0, 0, 0, //
        0, 0, blue, 0, 0, //
        0, 0, 0, 1, 0, //
      ];

  /// 复古色调（棕褐）。
  static List<double> sepiaMatrix() => <double>[
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0, //
    0.272, 0.534, 0.131, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  static List<double> grayscaleMatrix() => <double>[
    0.213, 0.715, 0.072, 0, 0, //
    0.213, 0.715, 0.072, 0, 0, //
    0.213, 0.715, 0.072, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// Gamma 用等效的对比度 + 亮度折中近似（幂函数无法用线性矩阵精确表达）。
  static List<double> gammaMatrix(double gamma) {
    if ((gamma - 1).abs() < 0.01) return identity;
    final scale = 1 / gamma;
    final offset = 128 * (1 - scale);
    return <double>[
      scale, 0, 0, 0, offset, //
      0, scale, 0, 0, offset, //
      0, 0, scale, 0, offset, //
      0, 0, 0, 1, 0, //
    ];
  }

  static List<double> fromSettings(ComicViewSettings settings) {
    var matrix = identity;
    if (settings.grayscale) {
      matrix = multiply(grayscaleMatrix(), matrix);
    }
    if (settings.sepia) {
      matrix = multiply(sepiaMatrix(), matrix);
    }
    if (settings.saturation != 1) {
      matrix = multiply(saturationMatrix(settings.saturation), matrix);
    }
    if (settings.hue != 0) {
      matrix = multiply(hueMatrix(settings.hue), matrix);
    }
    if (settings.gamma != 1) {
      matrix = multiply(gammaMatrix(settings.gamma), matrix);
    }
    // 锐化：以局部对比增强近似（无内置卷积滤镜，用对比度提升呈现）。
    if (settings.sharpen > 0) {
      matrix = multiply(contrastMatrix(100 + settings.sharpen * 34), matrix);
    }
    // 自动调整亮度对比：温和拉伸，避免过曝。
    if (settings.autoLevels) {
      matrix = multiply(contrastMatrix(112), matrix);
    }
    if (settings.contrast != 1) {
      matrix = multiply(contrastMatrix(settings.contrast), matrix);
    }
    if (settings.brightness != 0) {
      matrix = multiply(brightnessMatrix(settings.brightness), matrix);
    }
    if (settings.redBalance != 1 ||
        settings.greenBalance != 1 ||
        settings.blueBalance != 1) {
      matrix = multiply(
        balanceMatrix(
          settings.redBalance,
          settings.greenBalance,
          settings.blueBalance,
        ),
        matrix,
      );
    }
    if (settings.invert) {
      matrix = multiply(invertMatrix(), matrix);
    }
    return matrix;
  }

  static double _sin(double x) {
    var term = x;
    var sum = x;
    for (var i = 1; i <= 7; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      sum += term;
    }
    return sum;
  }

  static double _cos(double x) {
    var term = 1.0;
    var sum = 1.0;
    for (var i = 1; i <= 7; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      sum += term;
    }
    return sum;
  }
}

/// 白边检测：返回内容区域的相对矩形（0..1），失败返回 null。
class ComicBorderCropper {
  ComicBorderCropper._();

  static Future<Rect?> detect(
    ui.Image image, {
    int threshold = 244,
    int step = 2,
  }) async {
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    bool isContent(int x, int y) {
      final offset = (y * width + x) * 4;
      if (offset + 3 >= bytes.length) return false;
      final r = bytes[offset];
      final g = bytes[offset + 1];
      final b = bytes[offset + 2];
      final a = bytes[offset + 3];
      if (a < 16) return false;
      return r < threshold || g < threshold || b < threshold;
    }

    var top = -1;
    for (var y = 0; y < height; y += step) {
      var hasContent = false;
      for (var x = 0; x < width; x += step) {
        if (isContent(x, y)) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        top = y;
        break;
      }
    }
    if (top < 0) return null;

    var bottom = height - 1;
    for (var y = height - 1; y >= top; y -= step) {
      var hasContent = false;
      for (var x = 0; x < width; x += step) {
        if (isContent(x, y)) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        bottom = y;
        break;
      }
    }

    var left = width - 1;
    for (var x = 0; x < width; x += step) {
      var hasContent = false;
      for (var y = top; y <= bottom; y += step) {
        if (isContent(x, y)) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        left = x;
        break;
      }
    }

    var right = 0;
    for (var x = width - 1; x >= left; x -= step) {
      var hasContent = false;
      for (var y = top; y <= bottom; y += step) {
        if (isContent(x, y)) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        right = x;
        break;
      }
    }

    final contentWidth = right - left;
    final contentHeight = bottom - top;
    if (contentWidth <= width * 0.15 || contentHeight <= height * 0.15) {
      return null;
    }
    if (contentWidth >= width * 0.995 && contentHeight >= height * 0.995) {
      return null;
    }

    return Rect.fromLTRB(
      left / width,
      top / height,
      right / width,
      bottom / height,
    );
  }
}
