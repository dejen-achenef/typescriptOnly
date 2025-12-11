import 'package:share_plus/share_plus.dart';

class ShareUtils {
  const ShareUtils._();

  static Future<void> shareFiles(
    List<XFile> files, {
    String? text,
    String? subject,
  }) async {
    // ignore: deprecated_member_use
    await Share.shareXFiles(files, text: text, subject: subject);
  }

  static Future<void> shareText(String text, {String? subject}) async {
    // ignore: deprecated_member_use
    await Share.share(text, subject: subject);
  }
}

