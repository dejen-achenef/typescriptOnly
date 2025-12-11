import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart' as xml;

/// Service for exporting plain text content to PDF and DOCX files.
///
/// All files are written into the OS temporary directory so they can be
/// shared/opened immediately.
class ExportService {
  /// Exports [content] as a simple multi‑page PDF.
  ///
  /// Returns the resulting [File]. Throws [Exception] on failure.
  Future<File> exportToPdf({
    required String content,
    String? fileName,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Cannot export empty content as PDF.');
    }

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Text(
              trimmed,
              style: pw.TextStyle(
                fontSize: 12,
                lineSpacing: 1.3,
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();

      final baseName =
          (fileName?.trim().isNotEmpty ?? false) ? fileName!.trim() : _defaultFileName();
      final pdfName = baseName.endsWith('.pdf') ? baseName : '$baseName.pdf';

      final file = File('${tempDir.path}/$pdfName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// Exports [content] as a minimal DOCX file.
  ///
  /// The generated DOCX is a valid Office Open XML document.
  /// Returns the resulting [File]. Throws [Exception] on failure.
  Future<File> exportToDocx({
    required String content,
    String? fileName,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Cannot export empty content as DOCX.');
    }

    try {
      final tempDir = await getTemporaryDirectory();

      final baseName =
          (fileName?.trim().isNotEmpty ?? false) ? fileName!.trim() : _defaultFileName();
      final docxName = baseName.endsWith('.docx') ? baseName : '$baseName.docx';
      final filePath = '${tempDir.path}/$docxName';

      // Build a minimal DOCX archive.
      final archive = Archive();

      // [Content_Types].xml
      final contentTypes = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('Types'),
          [
            xml.XmlAttribute(
              xml.XmlName('xmlns'),
              'http://schemas.openxmlformats.org/package/2006/content-types',
            ),
          ],
          [
            xml.XmlElement(
              xml.XmlName('Default'),
              [
                xml.XmlAttribute(xml.XmlName('Extension'), 'rels'),
                xml.XmlAttribute(
                  xml.XmlName('ContentType'),
                  'application/vnd.openxmlformats-package.relationships+xml',
                ),
              ],
            ),
            xml.XmlElement(
              xml.XmlName('Default'),
              [
                xml.XmlAttribute(xml.XmlName('Extension'), 'xml'),
                xml.XmlAttribute(xml.XmlName('ContentType'), 'application/xml'),
              ],
            ),
            xml.XmlElement(
              xml.XmlName('Override'),
              [
                xml.XmlAttribute(
                  xml.XmlName('PartName'),
                  '/word/document.xml',
                ),
                xml.XmlAttribute(
                  xml.XmlName('ContentType'),
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml',
                ),
              ],
            ),
          ],
        ),
      ]);
      final contentTypesBytes = contentTypes.toString().codeUnits;
      archive.addFile(
        ArchiveFile('[Content_Types].xml', contentTypesBytes.length, contentTypesBytes),
      );

      // _rels/.rels
      final rels = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('Relationships'),
          [
            xml.XmlAttribute(
              xml.XmlName('xmlns'),
              'http://schemas.openxmlformats.org/package/2006/relationships',
            ),
          ],
          [
            xml.XmlElement(
              xml.XmlName('Relationship'),
              [
                xml.XmlAttribute(xml.XmlName('Id'), 'rId1'),
                xml.XmlAttribute(
                  xml.XmlName('Type'),
                  'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument',
                ),
                xml.XmlAttribute(xml.XmlName('Target'), 'word/document.xml'),
              ],
            ),
          ],
        ),
      ]);
      final relsBytes = rels.toString().codeUnits;
      archive.addFile(ArchiveFile('_rels/.rels', relsBytes.length, relsBytes));

      // word/_rels/document.xml.rels (minimal)
      final docRels = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('Relationships'),
          [
            xml.XmlAttribute(
              xml.XmlName('xmlns'),
              'http://schemas.openxmlformats.org/package/2006/relationships',
            ),
          ],
        ),
      ]);
      final docRelsBytes = docRels.toString().codeUnits;
      archive.addFile(
        ArchiveFile('word/_rels/document.xml.rels', docRelsBytes.length, docRelsBytes),
      );

      // Split content into paragraphs
      final paragraphs = trimmed
          .split(RegExp(r'\r?\n\r?\n|\r?\n'))
          .where((p) => p.trim().isNotEmpty)
          .toList();

      // word/document.xml
      final builder = xml.XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
      builder.element('w:document', nest: () {
        builder.attribute(
          'xmlns:w',
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        );
        builder.element('w:body', nest: () {
          for (final para in paragraphs) {
            builder.element('w:p', nest: () {
              builder.element('w:r', nest: () {
                builder.element('w:t', nest: () {
                  builder.text(para.trim());
                });
              });
            });
          }
        });
      });
      final document = builder.buildDocument();
      final docBytes = document.toString().codeUnits;
      archive.addFile(
        ArchiveFile('word/document.xml', docBytes.length, docBytes),
      );

      // word/settings.xml (minimal)
      final settings = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('w:settings'),
          [
            xml.XmlAttribute(
              xml.XmlName('xmlns:w'),
              'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
            ),
          ],
        ),
      ]);
      final settingsBytes = settings.toString().codeUnits;
      archive.addFile(
        ArchiveFile('word/settings.xml', settingsBytes.length, settingsBytes),
      );

      // word/styles.xml (minimal)
      final styles = xml.XmlDocument([
        xml.XmlElement(
          xml.XmlName('w:styles'),
          [
            xml.XmlAttribute(
              xml.XmlName('xmlns:w'),
              'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
            ),
          ],
        ),
      ]);
      final stylesBytes = styles.toString().codeUnits;
      archive.addFile(
        ArchiveFile('word/styles.xml', stylesBytes.length, stylesBytes),
      );

      // Encode archive into ZIP (.docx)
      final encoder = ZipEncoder();
      final zipData = encoder.encode(archive);

      if (zipData == null) {
        throw Exception('Failed to encode DOCX archive.');
      }

      final file = File(filePath);
      await file.writeAsBytes(zipData, flush: true);
      return file;
    } catch (e) {
      throw Exception('Failed to export DOCX: $e');
    }
  }

  String _defaultFileName() =>
      'translation_${DateTime.now().millisecondsSinceEpoch}';
}
