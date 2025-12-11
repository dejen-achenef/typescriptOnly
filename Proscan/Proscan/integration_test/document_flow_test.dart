import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/features/scan/services/export_service.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DocumentModelAdapter());
    await Hive.openBox<DocumentModel>(DocumentService.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('document lifecycle flow', (tester) async {
    await tester.runAsync(() async {
      final imagePaths = await _createTempImages(2);
      final options = DocumentSaveOptions.enterpriseDefaults(
        title: 'Integration Doc',
        tags: const ['integration', 'test'],
      );

      final savedDoc = await DocumentService.instance.saveDocument(
        pageImagePaths: imagePaths,
        title: 'Integration Doc',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.color,
        options: options,
      );

      expect(savedDoc.tags, contains('integration'));
      expect(savedDoc.metadata['title'], 'Integration Doc');

      final reopenedDocs = await DocumentService.instance.getAllDocumentsSafe();
      expect(reopenedDocs.any((doc) => doc.id == savedDoc.id), isTrue);

      await DocumentService.instance.renameDocument(
        savedDoc.id,
        'Renamed Integration Doc',
      );
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final renamed = box.get(savedDoc.id);
      expect(renamed?.title, 'Renamed Integration Doc');

      final updatedImages = await _createTempImages(1);
      final updatedDoc = await DocumentService.instance.updateDocument(
        documentId: savedDoc.id,
        pageImagePaths: updatedImages,
        title: 'Updated Integration Doc',
        scanMode: 'document',
        colorProfile: DocumentColorProfile.grayscale,
        options: const DocumentSaveOptions(
          compressionPreset: PdfCompressionPreset.archival,
          paperSize: PdfPaperSize.letter,
        ),
      );
      expect(updatedDoc.pageCount, 1);
      expect(updatedDoc.metadata['subject'], isNotEmpty);

      final exportService = ExportService();
      final exportedFile = await exportService.exportToPdf(
        content: 'Integration export content',
        fileName: 'integration_export',
      );
      expect(await exportedFile.exists(), isTrue);

      await DocumentService.instance.deleteDocument(savedDoc.id);
      expect(box.get(savedDoc.id), isNull);
    });
  });
}

Future<List<String>> _createTempImages(int count) async {
  final data = await rootBundle.load(
    'assets/images/dummythumbnails/thumbnailone.png',
  );
  final tempDir = await getTemporaryDirectory();
  final paths = <String>[];
  for (int i = 0; i < count; i++) {
    final filePath = p.join(tempDir.path, 'integration_image_$i.png');
    final file = File(filePath);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    paths.add(file.path);
  }
  return paths;
}
