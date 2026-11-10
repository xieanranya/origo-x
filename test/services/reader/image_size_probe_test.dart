// 文件说明：图片文件头尺寸解析单测。
//
// 覆盖 PNG / JPEG / GIF / BMP 四种常见格式，以及无法识别的垃圾数据。
// 这是阅读器排版高度计算的基础：解析错会让页面高度算错、滚动时重排跳跃。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/reader/image_size_probe.dart';

Uint8List _pngHeader(int width, int height) {
  final bytes = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // 签名
    0x00, 0x00, 0x00, 0x0D, // IHDR 长度
    0x49, 0x48, 0x44, 0x52, // "IHDR"
  ];
  void pushBe32(int value) {
    bytes.addAll([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  pushBe32(width);
  pushBe32(height);
  bytes.addAll([8, 6, 0, 0, 0]); // 位深 / 颜色类型等占位
  return Uint8List.fromList(bytes);
}

Uint8List _jpegHeader(int width, int height) {
  final bytes = <int>[
    0xFF, 0xD8, // SOI
    0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // 一个极小的 APP0 段
    0xFF, 0xC0, 0x00, 0x11, // SOF0，长度 17
    0x08, // 精度
    (height >> 8) & 0xFF, height & 0xFF,
    (width >> 8) & 0xFF, width & 0xFF,
    0x03, // 分量数
  ];
  return Uint8List.fromList(bytes);
}

Uint8List _gifHeader(int width, int height) {
  return Uint8List.fromList(<int>[
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"
    width & 0xFF, (width >> 8) & 0xFF,
    height & 0xFF, (height >> 8) & 0xFF,
    0x00, 0x00, 0x00,
  ]);
}

Uint8List _bmpHeader(int width, int height) {
  final bytes = <int>[0x42, 0x4D]; // "BM"
  while (bytes.length < 18) {
    bytes.add(0);
  }
  void pushLe32(int value) {
    bytes.addAll([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);
  }

  pushLe32(width);
  pushLe32(height);
  return Uint8List.fromList(bytes);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('probe_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<String> writeFile(String name, Uint8List bytes) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('PNG 宽高比', () async {
    final path = await writeFile('a.png', _pngHeader(800, 1200));
    expect(await probeAspectByHeader(path), closeTo(800 / 1200, 1e-6));
  });

  test('JPEG 宽高比', () async {
    final path = await writeFile('b.jpg', _jpegHeader(1024, 1536));
    expect(await probeAspectByHeader(path), closeTo(1024 / 1536, 1e-6));
  });

  test('GIF 宽高比', () async {
    final path = await writeFile('c.gif', _gifHeader(640, 480));
    expect(await probeAspectByHeader(path), closeTo(640 / 480, 1e-6));
  });

  test('BMP 宽高比（负高度按绝对值处理）', () async {
    final path = await writeFile('d.bmp', _bmpHeader(300, -600));
    expect(await probeAspectByHeader(path), closeTo(300 / 600, 1e-6));
  });

  test('无法识别的数据返回 null', () async {
    final path = await writeFile(
      'e.bin',
      Uint8List.fromList(List<int>.filled(64, 0x5A)),
    );
    expect(await probeAspectByHeader(path), isNull);
  });

  test('文件不存在返回 null（不抛异常）', () async {
    expect(await probeAspectByHeader('${tempDir.path}/missing.jpg'), isNull);
  });

  test('批量探测只返回成功项', () async {
    final png = await writeFile('x.png', _pngHeader(900, 1200));
    final junk = await writeFile('y.bin', Uint8List(32));
    final result = await probeAspectsByHeader(<String>[png, junk]);
    expect(result.length, 1);
    expect(result[png], closeTo(0.75, 1e-6));
  });
}
