part of 'router.dart';

/// Routes that don't require authentication
const _publicRoutes = [
  '/',
  '/onboarding',
  '/login',
  '/signup',
  '/forgotpassword',
  '/verifyotp',
  '/resetpassword',
];

/// Routes that should redirect to home if user is already authenticated
const _authRoutes = [
  '/login',
  '/signup',
  '/onboarding',
];

/// Checks if a route requires authentication
bool _requiresAuth(String location) {
  return !_publicRoutes.contains(location);
}

/// Checks if a route is an auth route (login/signup)
bool _isAuthRoute(String location) {
  return _authRoutes.contains(location);
}

final GoRouter router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    try {
      // Get current user from AuthService (singleton)
      final user = AuthService.instance.currentUser;
      final isAuthenticated = user != null;
      final location = state.matchedLocation;

      // If user is authenticated and trying to access auth routes, redirect to home
      if (isAuthenticated && _isAuthRoute(location)) {
        return '/appmainscreen';
      }

      // If user is not authenticated and trying to access protected routes, redirect to login
      if (!isAuthenticated && _requiresAuth(location)) {
        return '/login';
      }

      // No redirect needed
      return null;
    } catch (e) {
      // If AuthService is not initialized or there's an error, allow access to public routes
      final location = state.matchedLocation;
      if (_publicRoutes.contains(location)) {
        return null;
      }
      // For protected routes, redirect to login
      return '/login';
    }
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => SplashScreen()),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) {
        return OnboardingScreen();
      },
    ),
    GoRoute(
      path: '/signup',
      name: 'singup',
      builder: (context, state) {
        return SignupScreen();
      },
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) {
        return LoginScreen();
      },
    ),
    GoRoute(
      path: '/guesmodeprofilescreen',
      name: 'guesmodeprofilescreen',
      builder: (context, state) {
        return (ProfileGuestScreen());
      },
    ),
    GoRoute(
      path: '/premiumuserprofilescreen',
      name: 'premiumuserprofilescreen',
      builder: (context, state) {
        return (ProUserProfileScreen());
      },
    ),
    GoRoute(
      path: '/freeuserprofilescreen',
      name: 'freeuserprofilescreen',
      builder: (context, state) {
        return (FreeUserProfileScreen());
      },
    ),
    GoRoute(
      path: '/editprofilescreen',
      name: 'editprofilescreen',
      builder: (context, state) {
        return (EditProfileScreen());
      },
    ),
    GoRoute(
      path: '/forgotpassword',
      name: 'forgotpassword',
      builder: (context, state) {
        return ForgotPasswordScreen();
      },
    ),
    GoRoute(
      path: '/recentscansselection',
      name: 'recentscansselection',
      builder: (context, state) {
        return RecentScansSection();
      },
    ),
    GoRoute(
      path: '/verifyotp',
      name: 'verifyotp',
      builder: (context, state) {
        // TODO   pass the email
        final email = 'asnakemengesha79@gmail.com';
        return VerifyOtpScreen(email: email);
      },
    ),
    GoRoute(
      path: '/homescreen',
      name: 'homescreen',
      builder: (context, state) {
        return HomeScreen();
      },
    ),
    GoRoute(
      path: '/helpandsupport',
      name: 'helpandsupport',
      builder: (context, state) {
        return HelpSupportScreen();
      },
    ),
    GoRoute(
      path: '/appmainscreen',
      name: 'appmainscreen',
      builder: (context, state) {
        return AppMainScreen();
      },
    ),
    GoRoute(
      path: '/camerascreen',
      name: 'camerascreen',
      builder: (context, state) {
        final extra = state.extra;
        CameraScreenConfig? config;
        if (extra is CameraScreenConfig) {
          config = extra;
        } else if (extra is ScanMode) {
          config = CameraScreenConfig(initialMode: extra);
        }

        return SmartCameraScreen(
          initialMode: config?.initialMode ?? ScanMode.document,
          restrictToInitialMode: config?.restrictToInitialMode ?? false,
          returnCapturePath: config?.returnCapturePath ?? false,
          initialColorProfile: config?.colorProfile ?? DocumentColorProfile.color,
        );
      },
    ),
    GoRoute(
      path: '/editscanscreen',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is EditScanArgs) {
          return EditScanScreen(
            imagePath: extra.imagePath,
            initialMode: extra.initialMode,
            documentId: extra.documentId,
            imagePaths: extra.imagePaths,
            initialColorProfile: extra.colorProfile,
            documentTitle: extra.documentTitle,
          );
        } else if (extra is String && extra.isNotEmpty) {
          // Backwards compatibility: allow passing just the image path.
          return EditScanScreen(
            imagePath: extra,
            initialMode: ScanMode.document,
            initialColorProfile: DocumentColorProfile.color,
          );
        }
        throw ArgumentError('EditScanScreen requires image path.');
      },
    ),
    GoRoute(
      path: '/savepdfscreen',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          // Parse scanMode string to enum
          ScanMode? scanMode;
          if (extra['scanMode'] is String) {
            try {
              scanMode = ScanMode.values.firstWhere(
                (e) => e.toString().split('.').last == extra['scanMode'],
                orElse: () => ScanMode.document,
              );
            } catch (_) {}
          } else if (extra['scanMode'] is ScanMode) {
            scanMode = extra['scanMode'] as ScanMode;
          }

          DocumentColorProfile? colorProfile;
          final rawProfile = extra['colorProfile'];
          if (rawProfile is String) {
            colorProfile = DocumentColorProfile.fromKey(rawProfile);
          } else if (rawProfile is DocumentColorProfile) {
            colorProfile = rawProfile;
          }

          return SavePdfScreen(
            imagePaths: extra['imagePaths'] as List<String>,
            pdfFileName: extra['pdfFileName'] as String,
            documentId: extra['documentId'] as String?, // Optional for existing documents
            scanMode: scanMode,
            initialColorProfile: colorProfile,
          );
        }
        throw ArgumentError(
          'SavePdfScreen requires imagePaths and pdfFileName.',
        );
      },
    ),
    GoRoute(
      path: '/texteditorscreen',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          final imagePath = extra['imagePath'] as String?;
          final extractedText = extra['extractedText'] as String?;

          if (extractedText != null) {
            return TextEditorScreen(
              extractedText: extractedText,
              imagePath: imagePath,
            );
          } else if (imagePath != null) {
            // If only imagePath is provided, we'll process OCR in the screen
            return TextEditorScreen(extractedText: '', imagePath: imagePath);
          }
        }
        throw ArgumentError(
          'TextEditorScreen requires imagePath or extractedText.',
        );
      },
    ),
    GoRoute(
      path: '/resetpassword',
      name: 'resetpassword',
      builder: (context, state) {
        // TODO   pass the email
        final email = 'asnakemengesha79@gmail.com';
        return CreateNewPasswordScreen();
      },
    ),
    GoRoute(
      path: '/toolscreen',
      name: 'toolscreen',
      builder: (context, state) => const ToolsScreen(),
    ),
    GoRoute(
      path: '/translationeditorscreen',
      name: 'translationeditorscreen',
      builder: (context, state) {
        final extra = state.extra;
        String? documentId;
        if (extra is Map<String, dynamic>) {
          documentId = extra['documentId'] as String?;
        } else if (extra is String) {
          documentId = extra;
        }
        return TranslationEditorScreen(documentId: documentId);
      },
    ),
    GoRoute(
      path: '/textdocumentscreen',
      name: 'textdocumentscreen',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          return TextDocumentScreen(
            documentId: extra['documentId'] as String,
          );
        } else if (extra is String) {
          return TextDocumentScreen(documentId: extra);
        }
        throw ArgumentError('TextDocumentScreen requires documentId.');
      },
    ),
    GoRoute(
      path: '/searchscreen',
      name: 'searchscreen',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/upload-queue',
      name: 'upload-queue',
      builder: (context, state) => const UploadQueueScreen(),
    ),
    GoRoute(
      path: '/sync-settings',
      name: 'sync-settings',
      builder: (context, state) => const SyncSettingsScreen(),
    ),
    GoRoute(
      path: '/conflict-resolution',
      name: 'conflict-resolution',
      builder: (context, state) => const ConflictResolutionScreen(),
    ),
  ],
);
