// 文件说明：只读图片文件头的尺寸探测。
//
// 漫画页排版需要在渲染前知道每页的宽高比（垂直卷动时决定每页高度）。
// 原先用「读整文件 + instantiateImageCodec 解码」的方式探测：单页 50~200ms，
// 跑在主 isolate，滚动时每进入一页就卡一下，探测结果回填后页面高度还会变、
// 列表重新排版导致画面跳跃——向上翻动时尤其明显。
//
// 这里改为直接解析文件头（JPEG SOFn / PNG IHDR / GIF / BMP / WebP），
// 只读前几 KB，单页耗时约 0.1~0.5ms，可在滚动前把全部页面比例预先备齐，
// 排版高度一次定型，滚动过程中不再重排。
import 'dart:io';
import 'dart:typed_data';

/// 探测一批图片的宽高比（宽 / 高），解析不出的一律跳过（交给解码兜底）。
Future<Map<String, double>> probeAspectsByHeader(List<String> paths) async {
  final result = <String, double>{};
  for (final path in paths) {
    final aspect = await probeAspectByHeader(path);
    if (aspect != null) result[path] = aspect;
  }
  return result;
}

/// 探测单张图片的宽高比；无法识别格式或文件损坏时返回 null。
Future<double?> probeAspectByHeader(String path) async {
  RandomAccessFile? file;
  try {
    file = await File(path).open();
    // 先读 4KB：绝大多数文件头足够；JPEG 的 SOF 可能排在较大的 EXIF 之后，
    // 不够再按 64KB 递进，最多读 512KB，避免整文件读入。
    var size = 4096;
    Uint8List head = Uint8List(0);
    while (size <= 512 * 1024) {
      head = await file.read(size);
      final aspect = _parseAspect(head);
      if (aspect != null) return aspect;
      if (head.length < size) break; // 已到文件尾
      size *= 16;
    }
    return null;
  } catch (_) {
    return null; // 读失败按「未知」处理
  } finally {
    await file?.close();
  }
}

/// 按魔数分派到各格式解析器。
double? _parseAspect(Uint8List bytes) {
  if (bytes.length < 12) return null;
  // PNG：89 50 4E 47 0D 0A 1A 0A，IHDR 紧随其后，宽高为大端 32 位。
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    if (bytes.length < 24) return null;
    final width = _be32(bytes, 16);
    final height = _be32(bytes, 20);
    return _ratio(width, height);
  }
  // JPEG：FF D8，逐段找 SOF。
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return _parseJpeg(bytes);
  }
  // GIF：GIF87a / GIF89a，宽高为小端 16 位。
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    final width = _le16(bytes, 6);
    final height = _le16(bytes, 8);
    return _ratio(width, height);
  }
  // BMP：BM，宽高为小端 32 位；高度为 int32 补码，负数表示自上而下。
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
    final width = _le32(bytes, 18).abs();
    final height = _le32Signed(bytes, 22).abs();
    return _ratio(width, height);
  }
  // WebP：RIFF....WEBP。
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes.length >= 30 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return _parseWebp(bytes);
  }
  return null;
}

/// JPEG：跳过各段，命中 SOF0~SOF15（排除 C4/C8/CC）后取宽高。
double? _parseJpeg(Uint8List bytes) {
  var offset = 2;
  while (offset + 9 < bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];
    // 填充字节（FF FF）跳过。
    if (marker == 0xFF) {
      offset++;
      continue;
    }
    // 无长度字段的标记。
    if (marker == 0xD8 ||
        marker == 0xD9 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      offset += 2;
      continue;
    }
    final length = _be16(bytes, offset + 2);
    if (length < 2) return null;
    final isSof =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof) {
      final height = _be16(bytes, offset + 5);
      final width = _be16(bytes, offset + 7);
      return _ratio(width, height);
    }
    offset += 2 + length;
  }
  return null;
}

/// WebP：VP8（有损）/ VP8L（无损）/ VP8X（扩展）三种头。
double? _parseWebp(Uint8List bytes) {
  if (bytes.length < 30) return null;
  // 第一个 chunk 从偏移 12 开始：4 字节 fourcc + 4 字节长度。
  final fourcc = String.fromCharCodes(bytes.sublist(12, 16));
  switch (fourcc) {
    case 'VP8 ':
      // 关键帧起始码 9D 01 2A 后是 14 位宽、14 位高（小端）。
      if (bytes.length < 30) return null;
      final width = _le16(bytes, 26) & 0x3FFF;
      final height = _le16(bytes, 28) & 0x3FFF;
      return _ratio(width, height);
    case 'VP8L':
      // 偏移 21 起 32 位：14 位 (宽-1) + 14 位 (高-1)。
      if (bytes.length < 25) return null;
      final bits =
          bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
      final width = (bits & 0x3FFF) + 1;
      final height = ((bits >> 14) & 0x3FFF) + 1;
      return _ratio(width, height);
    case 'VP8X':
      // 画布宽高各 24 位（小端，值减 1）。
      if (bytes.length < 30) return null;
      final width = _le24(bytes, 24) + 1;
      final height = _le24(bytes, 27) + 1;
      return _ratio(width, height);
  }
  return null;
}

double? _ratio(int width, int height) {
  if (width <= 0 || height <= 0 || width > 200000 || height > 200000) {
    return null;
  }
  return width / height;
}

int _be16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];

int _be32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

int _le16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);

int _le24(Uint8List b, int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);

int _le32(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

/// 小端 32 位按 int32 补码解读（BMP 高度可能为负）。
int _le32Signed(Uint8List b, int o) {
  final value = _le32(b, o);
  return value >= 0x80000000 ? value - 0x100000000 : value;
}
