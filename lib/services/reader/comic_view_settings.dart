// 文件说明：漫画阅读的视图设置（翻页方向 / 白边裁剪 / 颜色校正）及其持久化。
// 技术要点：颜色校正合成单个 4x5 颜色矩阵，交给 GPU 一次完成，不额外增加绘制 pass。
import 'dart:convert';
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

/// 漫画视图设置。颜色参数与 Perfect Viewer 的调整项对齐。
@immutable
class ComicViewSettings {
  const ComicViewSettings({
    this.direction = ComicPageDirection.vertical,
    this.cropBorders = false,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.hue = 0,
    this.gamma = 1,
    this.invert = false,
    this.grayscale = false,
  });

  final ComicPageDirection direction;

  /// 自动裁掉页面四周的白边。
  final bool cropBorders;

  /// -100 ~ 100
  final double brightness;

  /// 50 ~ 200（百分比）
  final double contrast;

  /// 0 ~ 200（百分比）
  final double saturation;

  /// -180 ~ 180（度）
  final double hue;

  /// 50 ~ 200（百分比）
  final double gamma;

  final bool invert;
  final bool grayscale;

  bool get hasColorAdjust =>
      brightness != 0 ||
      contrast != 1 ||
      saturation != 1 ||
      hue != 0 ||
      gamma != 1 ||
      invert ||
      grayscale;

  ComicViewSettings copyWith({
    ComicPageDirection? direction,
    bool? cropBorders,
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    double? gamma,
    bool? invert,
    bool? grayscale,
  }) {
    return ComicViewSettings(
      direction: direction ?? this.direction,
      cropBorders: cropBorders ?? this.cropBorders,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      gamma: gamma ?? this.gamma,
      invert: invert ?? this.invert,
      grayscale: grayscale ?? this.grayscale,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'direction': direction.name,
    'cropBorders': cropBorders,
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'hue': hue,
    'gamma': gamma,
    'invert': invert,
    'grayscale': grayscale,
  };

  static ComicViewSettings fromJson(Map<String, dynamic> json) {
    ComicPageDirection parseDirection(Object? value) {
      for (final item in ComicPageDirection.values) {
        if (item.name == value) return item;
      }
      return ComicPageDirection.vertical;
    }

    double asDouble(Object? value, double fallback) =>
        value is num ? value.toDouble() : fallback;

    return ComicViewSettings(
      direction: parseDirection(json['direction']),
      cropBorders: json['cropBorders'] == true,
      brightness: asDouble(json['brightness'], 0),
      contrast: asDouble(json['contrast'], 1),
      saturation: asDouble(json['saturation'], 1),
      hue: asDouble(json['hue'], 0),
      gamma: asDouble(json['gamma'], 1),
      invert: json['invert'] == true,
      grayscale: json['grayscale'] == true,
    );
  }
}

/// 漫画视图设置的读写。
class ComicViewSettingsStore {
  const ComicViewSettingsStore();

  static const String _key = 'comic_view_settings_v1';

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

/// 把视图设置合成一个 4x5 颜色矩阵。
class ComicColorMatrix {
  ComicColorMatrix._();

  /// 单位矩阵。
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

  static List<double> grayscaleMatrix() => <double>[
    0.213, 0.715, 0.072, 0, 0, //
    0.213, 0.715, 0.072, 0, 0, //
    0.213, 0.715, 0.072, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// Gamma 校正用幂函数近似：以 1/gamma 的查表方式映射到对比度与亮度组合。
  static List<double> gammaMatrix(double gamma) {
    if ((gamma - 1).abs() < 0.01) return identity;
    // 幂函数无法用线性矩阵精确表达，这里用等效的对比度 + 亮度折中，
    // 足以覆盖漫画提亮暗部 / 压暗高光的常见需求。
    final scale = 1 / gamma;
    final offset = 128 * (1 - scale);
    return <double>[
      scale, 0, 0, 0, offset, //
      0, scale, 0, 0, offset, //
      0, 0, scale, 0, offset, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// 由视图设置合成最终矩阵。
  static List<double> fromSettings(ComicViewSettings settings) {
    var matrix = identity;
    if (settings.grayscale) {
      matrix = multiply(grayscaleMatrix(), matrix);
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
    if (settings.contrast != 1) {
      matrix = multiply(contrastMatrix(settings.contrast), matrix);
    }
    if (settings.brightness != 0) {
      matrix = multiply(brightnessMatrix(settings.brightness), matrix);
    }
    if (settings.invert) {
      matrix = multiply(invertMatrix(), matrix);
    }
    return matrix;
  }

  static double _sin(double x) {
    // 泰勒展开足够精确（-π..π）。
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

  /// 扫描图片边缘，找出非白内容范围。
  ///
  /// [threshold] 越大越激进（越容易把浅灰也算白边）。
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
      if (offset + 2 >= bytes.length) return false;
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

    // 几乎全白或几乎全幅时不做裁剪。
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
