// features/scan/core/services/file_export_service.dart
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart' as xml;
import 'package:thyscan/core/errors/failures.dart';

/// Service for exporting text to various file formats
class FileExportService {
  /// Helper to get a unique file path
  Future<String> _getUniqueFilePath(String directory, String fileName, String extension) async {
    String filePath = '$directory/$fileName$extension';
    int counter = 1;
    while (await File(filePath).exists()) {
      filePath = '$directory/$fileName ($counter)$extension';
      counter++;
    }
    return filePath;
  }

  /// Export text to a .docx (Word) file
  /// 
  /// Returns the path to the created file
  Future<String> exportToWord({
    required String text,
    String? fileName,
  }) async {
    try {
      // Generate file name if not provided
      final name = fileName ?? 'extracted_text_${DateTime.now().millisecondsSinceEpoch}';
      final baseName = name.endsWith('.docx') ? name.substring(0, name.length - 5) : name;

      // Get application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = await _getUniqueFilePath(directory.path, baseName, '.docx');

      // Create a basic .docx file structure
      // A .docx file is a ZIP archive containing XML files
      final archive = Archive();

      // Create [Content_Types].xml
      final contentTypes = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('Types'),
          [
            xml.XmlAttribute(xml.XmlName('xmlns'), 'http://schemas.openxmlformats.org/package/2006/content-types'),
          ],
          [
            xml.XmlElement(xml.XmlName('Default'), [
              xml.XmlAttribute(xml.XmlName('Extension'), 'rels'),
              xml.XmlAttribute(xml.XmlName('ContentType'), 'application/vnd.openxmlformats-package.relationships+xml'),
            ]),
            xml.XmlElement(xml.XmlName('Default'), [
              xml.XmlAttribute(xml.XmlName('Extension'), 'xml'),
              xml.XmlAttribute(xml.XmlName('ContentType'), 'application/xml'),
            ]),
            xml.XmlElement(xml.XmlName('Override'), [
              xml.XmlAttribute(xml.XmlName('PartName'), '/word/document.xml'),
              xml.XmlAttribute(xml.XmlName('ContentType'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'),
            ]),
          ],
        ),
      ]);
      archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.toString().codeUnits.length, contentTypes.toString().codeUnits));

      // Create _rels/.rels
      final rels = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('Relationships'),
          [
            xml.XmlAttribute(xml.XmlName('xmlns'), 'http://schemas.openxmlformats.org/package/2006/relationships'),
          ],
          [
            xml.XmlElement(xml.XmlName('Relationship'), [
              xml.XmlAttribute(xml.XmlName('Id'), 'rId1'),
              xml.XmlAttribute(xml.XmlName('Type'), 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument'),
              xml.XmlAttribute(xml.XmlName('Target'), 'word/document.xml'),
            ]),
          ],
        ),
      ]);
      archive.addFile(ArchiveFile('_rels/.rels', rels.toString().codeUnits.length, rels.toString().codeUnits));

      // Create word/_rels/document.xml.rels
      final docRels = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('Relationships'),
          [
            xml.XmlAttribute(xml.XmlName('xmlns'), 'http://schemas.openxmlformats.org/package/2006/relationships'),
          ],
        ),
      ]);
      archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRels.toString().codeUnits.length, docRels.toString().codeUnits));

      // Split text into paragraphs
      final paragraphs = text.split(RegExp(r'\n\s*\n|\n')).where((p) => p.trim().isNotEmpty).toList();
      
      // Create word/document.xml with paragraphs
      final documentBuilder = xml.XmlBuilder();
      documentBuilder.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
      documentBuilder.element('w:document', nest: () {
        documentBuilder.attribute('xmlns:w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        documentBuilder.element('w:body', nest: () {
          for (final paragraphText in paragraphs) {
            documentBuilder.element('w:p', nest: () {
              documentBuilder.element('w:r', nest: () {
                documentBuilder.element('w:t', nest: () {
                  documentBuilder.text(paragraphText.trim());
                });
              });
            });
          }
        });
      });
      final document = documentBuilder.buildDocument();
      archive.addFile(ArchiveFile('word/document.xml', document.toString().codeUnits.length, document.toString().codeUnits));

      // Create word/settings.xml (minimal)
      final settings = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('w:settings'),
          [
            xml.XmlAttribute(xml.XmlName('xmlns:w'), 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'),
          ],
        ),
      ]);
      archive.addFile(ArchiveFile('word/settings.xml', settings.toString().codeUnits.length, settings.toString().codeUnits));

      // Create word/styles.xml (minimal)
      final styles = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('w:styles'),
          [
            xml.XmlAttribute(xml.XmlName('xmlns:w'), 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'),
          ],
        ),
      ]);
      archive.addFile(ArchiveFile('word/styles.xml', styles.toString().codeUnits.length, styles.toString().codeUnits));

      // Compress and save the archive
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      
      if (zipData != null) {
        final file = File(filePath);
        await file.writeAsBytes(zipData);
        return filePath;
      }

      throw const ExportFailure('Failed to encode DOCX file');
    } catch (e) {
      throw ExportFailure('Failed to create Word document: $e');
    }
  }

  /// Export text to a .txt file
  /// 
  /// Returns the path to the created file
  Future<String> exportToText({
    required String text,
    String? fileName,
  }) async {
    try {
      final name = fileName ?? 'extracted_text_${DateTime.now().millisecondsSinceEpoch}';
      final baseName = name.endsWith('.txt') ? name.substring(0, name.length - 4) : name;

      final directory = await getApplicationDocumentsDirectory();
      final filePath = await _getUniqueFilePath(directory.path, baseName, '.txt');

      final file = File(filePath);
      await file.writeAsBytes(text.codeUnits);

      return filePath;
    } catch (e) {
      throw ExportFailure('Failed to create text file: $e');
    }
  }
}
