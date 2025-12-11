import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/features/scan/core/services/pdf_generation_service.dart';
import 'package:thyscan/services/pdf_builder.dart';
import 'package:thyscan/services/pdf_preprocessor.dart';

/// Provider for the PDF generation service (isolate-based).
final pdfGenerationProvider = Provider<PdfGenerationService>((ref) {
  return PdfGenerationService.instance;
});

/// Provider for the PDF preprocessor service.
final pdfPreprocessorProvider = Provider<PdfPreprocessor>((ref) {
  return PdfPreprocessor.instance;
});

/// Provider for the PDF builder service.
final pdfBuilderProvider = Provider<PdfBuilder>((ref) {
  return PdfBuilder.instance;
});

/// Provider for document save options state.
final documentSaveOptionsProvider = Provider<DocumentSaveOptions>((ref) {
  return const DocumentSaveOptions();
});
