// core/constants/app_directories.dart
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

/// Main app folder name in Documents directory
const String appMainFolder = 'ThyScan';

/// Mapping of ScanMode to folder names for organized document storage
/// 
/// Each scan mode has its own folder inside ThyScan/ for easy organization.
/// Users can navigate to these folders to find their documents.
const Map<ScanMode, String> scanModeFolders = {
  ScanMode.document: 'Document',
  ScanMode.idCard: 'ID Card',
  ScanMode.book: 'Book',
  ScanMode.scanCode: 'Barcode',
  ScanMode.extractText: 'Text',
  ScanMode.translate: 'Translate',
  ScanMode.timestamp: 'Timestamp',
  ScanMode.excel: 'Excel',
  ScanMode.slides: 'Slides',
  ScanMode.word: 'Word',
  ScanMode.question: 'Question',
};

/// Gets the folder name for a scan mode string (backward compatibility)
/// 
/// Used when we have a string scanMode from DocumentModel instead of ScanMode enum.
/// The scanMode string is typically stored as the enum name (e.g., "document", "idCard", "extractText").
String getFolderNameForScanMode(String scanMode) {
  try {
    // Normalize the scan mode string (handle case variations)
    final normalized = scanMode.trim();
    
    // Try to find matching ScanMode enum by name
    ScanMode? matchedMode;
    try {
      matchedMode = ScanMode.values.firstWhere(
        (m) => m.name.toLowerCase() == normalized.toLowerCase(),
      );
    } catch (_) {
      // Enum not found by exact name match, try alternative mappings
      // Handle legacy or alternative names if any
    }
    
    // Use matched mode or default to document
    final mode = matchedMode ?? ScanMode.document;
    return scanModeFolders[mode] ?? 'Document';
  } catch (e) {
    // Fallback to default folder if scan mode is unknown
    return 'Document';
  }
}

/// Gets the folder name for a ScanMode enum
String getFolderName(ScanMode scanMode) {
  return scanModeFolders[scanMode] ?? 'Document';
}

