// 文件说明：漫画压缩包（CBZ / ZIP）的解压、导入与图片枚举。
// 技术要点：只抽取图片条目、按自然序排序；导入后书籍记录复用现有 books 表，
// 阅读时由 ComicReaderPage 以图片流方式呈现，与 TXT / EPUB 完全同库。
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/book.dart';
import 'book_dao.dart';
import 'cover_generator_service.dart';

/// 漫画压缩包支持服务。
class ComicArchiveService {
  ComicArchiveService._();

  /// 支持的图片扩展名。
  static const Set<String> imageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
  };

  /// 支持的漫画压缩包扩展名。
  static const Set<String> archiveExtensions = <String>{'cbz', 'zip'};

  /// 判断扩展名是否为受支持的漫画压缩包。
  static bool isComicArchive(String extension) =>
      archiveExtensions.contains(extension.toLowerCase());

  /// 自然序比较：让 page2 排在 page10 前面。
  static int naturalCompare(String a, String b) {
    final left = a.codeUnits;
    final right = b.codeUnits;
    var i = 0;
    var j = 0;
    while (i < left.length && j < right.length) {
      final aDigit = left[i] >= 48 && left[i] <= 57;
      final bDigit = right[j] >= 48 && right[j] <= 57;
      if (aDigit && bDigit) {
        var aNumber = 0;
        while (i < left.length && left[i] >= 48 && left[i] <= 57) {
          aNumber = aNumber * 10 + (left[i] - 48);
          i++;
        }
        var bNumber = 0;
        while (j < right.length && right[j] >= 48 && right[j] <= 57) {
          bNumber = bNumber * 10 + (right[j] - 48);
          j++;
        }
        if (aNumber != bNumber) return aNumber - bNumber;
        continue;
      }
      if (left[i] != right[j]) return left[i] - right[j];
      i++;
      j++;
    }
    return left.length - right.length;
  }

  /// 解压压缩包中的图片到 [targetDir]，返回排序后的文件名。
  static Future<List<String>> extractImages(
    File archiveFile,
    Directory targetDir,
  ) async {
    final bytes = await archiveFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    await targetDir.create(recursive: true);
    final names = <String>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final base = p.basename(entry.name);
      if (base.isEmpty || base.startsWith('.')) continue;
      final extension = p.extension(base).toLowerCase().replaceFirst('.', '');
      if (!imageExtensions.contains(extension)) continue;
      final output = File(p.join(targetDir.path, base));
      final content = entry.content;
      if (content == null) continue;
      await output.writeAsBytes(content, flush: true);
      names.add(base);
    }
    names.sort(naturalCompare);
    return names;
  }

  /// 导入一个漫画压缩包，返回新建的书籍记录；没有可用图片时返回 null。
  static Future<Book?> importComic(
    File archiveFile, {
    BookDao? dao,
  }) async {
    final extension = p.extension(archiveFile.path).replaceFirst('.', '');
    if (!isComicArchive(extension)) return null;

    final documentsDir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeTitle = p.basenameWithoutExtension(archiveFile.path);
    final bookDir = Directory(
      p.join(documentsDir.path, 'comics', '${stamp}_$safeTitle'),
    );

    List<String> names;
    try {
      names = await extractImages(archiveFile, bookDir);
    } catch (_) {
      if (await bookDir.exists()) await bookDir.delete(recursive: true);
      rethrow;
    }
    if (names.isEmpty) {
      if (await bookDir.exists()) await bookDir.delete(recursive: true);
      return null;
    }

    // 封面取第一页，交给统一的封面持久化逻辑。
    String? coverPath;
    try {
      final firstPage = File(p.join(bookDir.path, names.first));
      final bytes = await firstPage.readAsBytes();
      coverPath = await CoverGenerator.saveCover(
        bytes,
        archiveFile.path,
        fileTag: 'comic-cover',
      );
    } catch (_) {
      coverPath = null;
    }

    final book = Book(
      title: safeTitle,
      author: '',
      filePath: bookDir.path,
      format: extension.toUpperCase(),
      currentPage: 0,
      totalPages: names.length,
      readingProgress: 0,
      importDate: DateTime.now(),
      coverImagePath: coverPath,
    );
    final bookDao = dao ?? BookDao();
    final id = await bookDao.insertBook(book);
    return book.copyWith(id: id);
  }
}
