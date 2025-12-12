// core/config/app_env.dart
import 'package:envied/envied.dart';
part 'app_env.g.dart';

/// Production-grade environment configuration using compile-time obfuscation.
///
/// This class securely manages Supabase credentials using the `envied` package.
/// Values are obfuscated at compile-time and never appear in plain text in the binary.
///
/// To use:
/// 1. Update the `.env` file with your actual credentials
/// 2. Run `flutter pub run build_runner build` to generate the obfuscated code
/// 3. Access values via `AppEnv.supabaseUrl` and `AppEnv.supabaseAnonKey`
@Envied(path: '.env')
abstract class AppEnv {
  @EnviedField(varName: 'SUPABASE_URL', obfuscate: true)
  static final String supabaseUrl = _AppEnv.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY', obfuscate: true)
  static String supabaseAnonKey = _AppEnv.supabaseAnonKey;

  @EnviedField(varName: 'GOOGLE_WEB_CLIENT_ID', obfuscate: true)
  static String googleWebClientId = _AppEnv.googleWebCliendsdf;

  @EnviedField(varName: 'BACKEND_API_URL', obfuscate: true, optional: true)
  static String? backendApiUrl = _AppEnv.backendApiUrl;

  @EnviedField(
    varName: 'REQUEST_SIGNATURE_SECRET',
    obfuscate: true,
    optional: true,
  )
  static String? requestSignatureSecret = _AppEnv.requestSignatureSecret;
}
