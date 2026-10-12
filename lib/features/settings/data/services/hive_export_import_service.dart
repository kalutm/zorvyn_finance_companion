import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:finance_frontend/core/storage/hive_bootstrap.dart';
import 'package:finance_frontend/core/storage/hive_box_names.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Handles exporting all Hive box files to a single `.zip` archive and
/// restoring them from such an archive.
///
/// **Export flow**
/// 1. Close every open Hive box so pending writes are flushed to disk.
/// 2. Locate every `*.hive` file in the app documents directory.
/// 3. Zip them into `zorvyn_backup_<timestamp>.zip` in the cache directory.
/// 4. Reopen boxes so the rest of the app can continue working.
/// 5. Return the path of the zip file so the caller can share it.
///
/// **Import flow**
/// 1. Close every open Hive box.
/// 2. Unzip the chosen file, overwriting each `*.hive` file in the documents
///    directory.
/// 3. Reopen boxes so the rest of the app can continue working.
class HiveExportImportService {
  static const _boxNames = [
    HiveBoxNames.accounts,
    HiveBoxNames.categories,
    HiveBoxNames.transactions,
    HiveBoxNames.budgets,
    HiveBoxNames.meta,
  ];

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Closes every known Hive box that is currently open.
  Future<void> _closeAllBoxes() async {
    for (final name in _boxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<dynamic>(name).close();
      }
    }
  }

  /// Reopens every known Hive box so the rest of the app can continue.
  Future<void> _reopenAllBoxes() async {
    await HiveBootstrap.ensureInitialized();
    for (final name in _boxNames) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<dynamic>(name);
      }
    }
  }

  // ── public API ────────────────────────────────────────────────────────────

  /// Exports all Hive data to a zip archive.
  ///
  /// Returns the absolute path of the created `.zip` file.
  /// Throws a [HiveExportException] if anything goes wrong.
  Future<String> exportData() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getTemporaryDirectory();

      // 1. Close boxes so all data is flushed.
      await _closeAllBoxes();

      // 2. Collect *.hive files.
      final hiveFiles =
          docsDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.hive'))
              .toList();

      if (hiveFiles.isEmpty) {
        await _reopenAllBoxes();
        throw HiveExportException('No Hive data files found to export.');
      }

      // 3. Build zip archive.
      final encoder = ZipFileEncoder();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipPath = '${cacheDir.path}/zorvyn_backup_$timestamp.zip';
      encoder.create(zipPath);

      for (final file in hiveFiles) {
        // Store only the filename (no directory) so the zip is flat.
        encoder.addFile(file, file.uri.pathSegments.last);
      }

      encoder.close();

      // 4. Reopen boxes.
      await _reopenAllBoxes();

      return zipPath;
    } on HiveExportException {
      await _reopenAllBoxes();
      rethrow;
    } catch (e) {
      await _reopenAllBoxes();
      throw HiveExportException('Export failed: $e');
    }
  }

  /// Imports Hive data from a `.zip` archive at [zipPath].
  ///
  /// Overwrites existing `.hive` files in the app documents directory.
  /// Throws a [HiveImportException] if anything goes wrong.
  Future<void> importData(String zipPath) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();

      // 1. Close boxes first.
      await _closeAllBoxes();

      // 2. Read & extract the zip.
      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      bool anyExtracted = false;
      for (final entry in archive) {
        if (!entry.isFile) continue;
        if (!entry.name.endsWith('.hive')) continue;

        final outFile = File('${docsDir.path}/${entry.name}');
        outFile.writeAsBytesSync(entry.content as List<int>);
        anyExtracted = true;
      }

      if (!anyExtracted) {
        await _reopenAllBoxes();
        throw HiveImportException(
          'The selected file contains no valid Hive data.',
        );
      }

      // 3. Reopen boxes with restored data.
      await _reopenAllBoxes();
    } on HiveImportException {
      await _reopenAllBoxes();
      rethrow;
    } catch (e) {
      await _reopenAllBoxes();
      throw HiveImportException('Import failed: $e');
    }
  }
}

// ── Custom exceptions ─────────────────────────────────────────────────────

class HiveExportException implements Exception {
  final String message;
  const HiveExportException(this.message);
  @override
  String toString() => message;
}

class HiveImportException implements Exception {
  final String message;
  const HiveImportException(this.message);
  @override
  String toString() => message;
}
