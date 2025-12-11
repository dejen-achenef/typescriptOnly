// core/services/auth_service.dart
import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thyscan/core/config/app_env.dart';
import 'package:thyscan/core/errors/failures.dart';
import 'package:thyscan/core/models/app_user.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/background_sync_service.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/core/services/document_search_service.dart';
import 'package:thyscan/core/services/document_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/core/services/full_text_search_index_service.dart';
import 'package:thyscan/core/services/recent_searches_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Singleton service for handling authentication with Supabase.
/// Supports email/password and Google Sign-In.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool _isInitialized = false;
  bool _isInitializing = false;
  SupabaseClient? _supabase;
  final _userController = StreamController<AppUser?>.broadcast();
  final _initCompleter = Completer<void>();

  /// Gets the Supabase client instance.
  /// Throws [StateError] if not initialized.
  SupabaseClient get supabase {
    if (!_isInitialized || _supabase == null) {
      throw StateError('AuthService not initialized. Call init() first.');
    }
    return _supabase!;
  }

  /// Waits for AuthService to be initialized.
  /// Returns immediately if already initialized.
  /// Starts initialization if not already started.
  /// Throws [AuthFailure] if initialization fails.
  /// OPTIMIZED: Uses shorter timeout for faster failure detection.
  Future<void> ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    // If init hasn't been called yet, start it now
    if (!_initCompleter.isCompleted) {
      // Start initialization in the background (don't await, let completer handle it)
      init().catchError((error) {
        // Error is already handled in init() and completer is completed with error
        AppLogger.error('ensureInitialized: init() failed', error: error);
      });
    }

    // Wait for initialization to complete (with shorter timeout for faster UX)
    try {
      await _initCompleter.future.timeout(
        const Duration(seconds: 5), // Reduced from 15s to 5s for faster failure
        onTimeout: () {
          // Check if init is still running
          if (_isInitializing) {
            AppLogger.error(
              'Init still running after timeout - likely network issue or Supabase.initialize() hanging',
            );
          }
          // Don't throw - allow app to continue in guest mode
          // Just log and return (offline-first approach)
          AppLogger.warning(
            'AuthService initialization timed out - continuing in guest mode',
            error: null,
          );
        },
      );
    } catch (e) {
      if (e is AuthFailure) {
        // For auth failures, still throw
        rethrow;
      }
      // For other errors, log but don't block (offline-first)
      AppLogger.error(
        'AuthService initialization had an issue - continuing in guest mode',
        error: e,
      );
      // Don't throw - allow app to continue
    }
  }

  /// Initializes Supabase with PKCE flow for deep linking support.
  /// Reads SUPABASE_URL and SUPABASE_ANON_KEY from environment or uses defaults.
  Future<void> init() async {
    // DIAGNOSTIC: Plain print at very top (before any state changes)
    print('DEBUG_PLAIN: AuthService.init() entered');

    // DIAGNOSTIC: Safe AppEnv sample logging (before any trimming/validation)
    final rawUrl = AppEnv.supabaseUrl;
    final rawKey = AppEnv.supabaseAnonKey;
    final urlLength = rawUrl?.length ?? 0;
    final keyLength = rawKey?.length ?? 0;
    final urlSample = urlLength > 12
        ? '${rawUrl!.substring(0, 6)}...${rawUrl.substring(urlLength - 6)}'
        : (rawUrl ?? 'null');
    AppLogger.info(
      'DEBUG: AppEnv raw values (sanitized)',
      data: {
        'urlLength': urlLength,
        'keyLength': keyLength,
        'urlSample': urlSample,
      },
    );
    // Also print to stdout for logcat visibility
    print(
      'DEBUG: AppEnv urlLength=$urlLength, keyLength=$keyLength, urlSample=$urlSample',
    );

    if (_isInitialized) {
      print('DEBUG: Already initialized, returning early');
      AppLogger.warning('AuthService already initialized', error: null);
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      return;
    }

    // Prevent multiple concurrent initialization calls
    if (_isInitializing) {
      print('DEBUG: Already initializing, waiting...');
      AppLogger.info(
        'AuthService initialization already in progress, waiting...',
      );
      await _initCompleter.future;
      return;
    }

    print('DEBUG: Setting _isInitializing = true');
    _isInitializing = true;

    try {
      print(
        'DEBUG: Entered try block, checking if Supabase is already initialized',
      );
      // Check if Supabase is already initialized (using try-catch since accessing
      // Supabase.instance throws if not initialized)
      bool isAlreadyInitialized = false;
      SupabaseClient? existingClient;
      try {
        existingClient = Supabase.instance.client;
        isAlreadyInitialized = true;
        print(
          'DEBUG: Supabase.instance.isInitialized = true (existing instance found)',
        );
      } catch (e) {
        // Supabase.instance throws if not initialized - this is expected on first init
        print(
          'DEBUG: Supabase.instance not initialized yet (expected on first init)',
        );
        isAlreadyInitialized = false;
      }

      if (isAlreadyInitialized && existingClient != null) {
        print('DEBUG: Using existing Supabase instance');
        _supabase = existingClient;
        AppLogger.info('Using existing Supabase instance');
      } else {
        print('DEBUG: Supabase not initialized, starting new initialization');
        // Initialize with PKCE flow for deep linking support
        // Credentials are loaded from .env file via envied (compile-time obfuscated)
        String supabaseUrl;
        String supabaseAnonKey;

        try {
          print('DEBUG: Loading credentials from AppEnv');
          supabaseUrl = AppEnv.supabaseUrl.trim(); // Trim whitespace
          supabaseAnonKey = AppEnv.supabaseAnonKey.trim();
          print(
            'DEBUG: Credentials loaded - urlLength=${supabaseUrl.length}, keyLength=${supabaseAnonKey.length}',
          );

          // Remove trailing slash if present
          if (supabaseUrl.endsWith('/')) {
            print('DEBUG: Removing trailing slash from URL');
            supabaseUrl = supabaseUrl.substring(0, supabaseUrl.length - 1);
          }

          print(
            'DEBUG: Validating URL format - startsWith https://: ${supabaseUrl.startsWith('https://')}, endsWith .supabase.co: ${supabaseUrl.endsWith('.supabase.co')}',
          );
          // Validate URL format
          if (!supabaseUrl.startsWith('https://') ||
              !supabaseUrl.endsWith('.supabase.co')) {
            final urlSample = supabaseUrl.length > 50
                ? '${supabaseUrl.substring(0, 25)}...${supabaseUrl.substring(supabaseUrl.length - 25)}'
                : supabaseUrl;
            print('DEBUG: URL validation failed - urlSample=$urlSample');
            AppLogger.error(
              'Invalid Supabase URL format',
              data: {'url': urlSample},
            );
            throw AuthFailure(
              'Invalid Supabase URL format. URL must start with https:// and end with .supabase.co',
            );
          }
          print('DEBUG: URL validation passed');

          AppLogger.info(
            'Loaded Supabase credentials from AppEnv',
            data: {
              'url': supabaseUrl, // Log actual URL for debugging
              'urlLength': supabaseUrl.length,
              'keyLength': supabaseAnonKey.length,
            },
          );
        } catch (e, stack) {
          print(
            'DEBUG: Exception in credential loading - type: ${e.runtimeType}, message: ${e.toString()}',
          );
          if (e is AuthFailure) {
            rethrow;
          }
          AppLogger.error(
            'Failed to load AppEnv credentials',
            error: e,
            stack: stack,
          );
          print('DEBUG: Stack trace: $stack');
          throw AuthFailure(
            'Failed to load Supabase credentials. Please ensure .env file exists and run: flutter pub run build_runner build --delete-conflicting-outputs',
          );
        }

        print('DEBUG: Checking if credentials are empty');
        if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
          print(
            'DEBUG: Credentials are empty - urlEmpty=${supabaseUrl.isEmpty}, keyEmpty=${supabaseAnonKey.isEmpty}',
          );
          AppLogger.error(
            'Supabase credentials are empty',
            data: {
              'urlEmpty': supabaseUrl.isEmpty,
              'keyEmpty': supabaseAnonKey.isEmpty,
            },
          );
          throw AuthFailure(
            'Supabase credentials are empty. Please ensure .env file has valid SUPABASE_URL and SUPABASE_ANON_KEY, then run: flutter pub run build_runner build --delete-conflicting-outputs',
          );
        }
        print('DEBUG: Credentials are not empty, proceeding to initialize');

        AppLogger.info('Initializing Supabase with PKCE flow...');
        print('DEBUG: About to call Supabase.initialize()');
        try {
          // DEBUG: Log before initialize with sanitized URL sample
          final sanitizedUrlSample = supabaseUrl.length > 12
              ? '${supabaseUrl.substring(0, 6)}...${supabaseUrl.substring(supabaseUrl.length - 6)}'
              : supabaseUrl;
          AppLogger.info(
            'DEBUG: Calling Supabase.initialize() (30s timeout for debug)',
            data: {
              'urlSample': sanitizedUrlSample,
              'urlLength': supabaseUrl.length,
              'keyLength': supabaseAnonKey.length,
            },
          );
          print(
            'DEBUG: Calling Supabase.initialize() with urlSample=$sanitizedUrlSample, urlLength=${supabaseUrl.length}, keyLength=${supabaseAnonKey.length}',
          );

          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseAnonKey,
            authOptions: FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
            ),
          ).timeout(
            const Duration(seconds: 30), // Increased timeout for debugging
            onTimeout: () {
              throw TimeoutException(
                'Supabase initialization timed out after 30 seconds. This may indicate a network issue or PKCE flow problem.',
                const Duration(seconds: 30),
              );
            },
          );

          _supabase = Supabase.instance.client;
          AppLogger.info('Supabase initialized successfully with PKCE flow');
          print('DEBUG: Supabase.initialize() returned successfully');
        } catch (e, stack) {
          // DEBUG: Full exception logging with stack trace
          AppLogger.error(
            'Supabase.initialize() failed',
            error: e,
            stack: stack,
            data: {
              'errorType': e.runtimeType.toString(),
              'errorMessage': e.toString(),
            },
          );
          print('DEBUG: Supabase.initialize() failed');
          print('DEBUG: Exception type: ${e.runtimeType}');
          print('DEBUG: Exception message: ${e.toString()}');
          print('DEBUG: Stack trace: $stack');

          // OFFLINE-FIRST: If network error, continue in guest mode (don't throw)
          // Only throw for invalid credentials, not network issues
          final isNetworkError =
              e is TimeoutException ||
              e.toString().contains('SocketException') ||
              e.toString().contains('Network') ||
              e.toString().contains('connection') ||
              e.toString().contains('Failed host lookup');

          if (isNetworkError) {
            // Network error - continue in guest mode (offline-first)
            AppLogger.warning(
              'Supabase initialization failed due to network error. Continuing in guest mode.',
              error: null,
            );
            print('DEBUG: Network error detected - continuing in guest mode');
            // Don't throw - allow app to continue in guest mode
            // _isInitialized will remain false, but app won't crash
            _isInitializing = false;
            if (!_initCompleter.isCompleted) {
              _initCompleter
                  .complete(); // Complete without error to allow app to continue
            }
            return; // Exit gracefully - app continues in guest mode
          }

          // For non-network errors (invalid credentials, etc.), still throw
          String errorMessage;
          if (e.toString().contains('Invalid') ||
              e.toString().contains('credentials')) {
            errorMessage =
                'Invalid Supabase credentials. Please check your .env file and regenerate with: flutter pub run build_runner build --delete-conflicting-outputs';
          } else {
            errorMessage =
                'Failed to initialize Supabase: ${e.toString()}. Please check your configuration.';
          }

          throw AuthFailure(errorMessage);
        }
      }

      // Listen to auth state changes and transform to AppUser stream
      try {
        supabase.auth.onAuthStateChange.listen((data) {
          final event = data.event;
          final session = data.session;

          AppLogger.info(
            'Auth state changed: ${event.toString()}',
            data: {'hasSession': session != null},
          );

          // Handle token refresh events explicitly
          if (event == AuthChangeEvent.tokenRefreshed) {
            AppLogger.info(
              'Token refreshed successfully',
              data: {
                'hasSession': session != null,
                'userId': session?.user?.id,
              },
            );
            // Token refresh succeeded - emit user to ensure UI is updated
            if (session?.user != null) {
              final appUser = AppUser.fromSupabase(session!.user!);
              _userController.add(appUser);
            }
          } else if (event == AuthChangeEvent.signedOut) {
            AppLogger.warning(
              'User signed out unexpectedly (token may have expired or been revoked)',
              error: null,
              data: {'hasSession': session != null},
            );
            _userController.add(null);
          } else if (event == AuthChangeEvent.userUpdated) {
            AppLogger.info(
              'User data updated',
              data: {
                'hasSession': session != null,
                'userId': session?.user?.id,
              },
            );
            if (session?.user != null) {
              final appUser = AppUser.fromSupabase(session!.user!);
              _userController.add(appUser);
            }
          }

          // Handle general user state
          final user = session?.user;
          if (user != null) {
            // Only emit if not already handled by specific event handlers above
            if (event != AuthChangeEvent.tokenRefreshed &&
                event != AuthChangeEvent.userUpdated) {
              final appUser = AppUser.fromSupabase(user);
              _userController.add(appUser);
              AppLogger.info('User authenticated: ${appUser.email}');
            }
          } else if (event != AuthChangeEvent.signedOut) {
            // Only emit null if not already handled by signedOut event
            _userController.add(null);
            AppLogger.info('User signed out');
          }
        });
        AppLogger.info('Auth state change listener registered with token refresh monitoring');
      } catch (e, stack) {
        AppLogger.error(
          'Failed to register auth state listener',
          error: e,
          stack: stack,
        );
        // Don't throw - we can still use the service, just won't get real-time updates
      }

      _isInitialized = true;
      _isInitializing = false;
      AppLogger.info('AuthService initialized successfully');

      // Emit initial user state to stream once initialized
      try {
        final initialUser = currentUser;
        _userController.add(initialUser);
        AppLogger.info(
          'Emitted initial user state',
          data: {'hasUser': initialUser != null},
        );
      } catch (e, stack) {
        AppLogger.error(
          'Failed to emit initial user state',
          error: e,
          stack: stack,
        );
        // Continue - not critical
      }

      // Complete the initialization completer
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
        AppLogger.info('Initialization completer completed');
      }
    } catch (e, stack) {
      _isInitializing = false;
      AppLogger.error(
        'Failed to initialize AuthService',
        error: e,
        stack: stack,
        data: {
          'errorType': e.runtimeType.toString(),
          'errorMessage': e.toString(),
        },
      );

      // Complete with error if not already completed
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
        AppLogger.info('Initialization completer completed with error');
      }

      // Extract user-friendly error message
      String errorMessage;
      if (e is AuthFailure) {
        errorMessage = e.message;
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Network') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('Invalid') ||
          e.toString().contains('credentials')) {
        errorMessage =
            'Invalid Supabase credentials. Please check your .env file and regenerate with: flutter pub run build_runner build --delete-conflicting-outputs';
      } else {
        errorMessage = 'Failed to initialize authentication: ${e.toString()}';
      }

      throw AuthFailure(errorMessage);
    }
  }

  /// Signs up a new user with email and password.
  /// Optionally sets the user's full name in metadata.
  /// Returns true if email confirmation is required, false if user is immediately signed in.
  Future<bool> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    // Ensure AuthService is initialized before proceeding
    await ensureInitialized();

    try {
      AppLogger.info('Signing up user with email', data: {'email': email});

      // 1. Determine Device Type
      String deviceType = 'other';
      if (Platform.isAndroid) {
        deviceType = 'android';
      } else if (Platform.isIOS) {
        deviceType = 'ios';
      }

      // 2. Construct Metadata
      final userData = <String, dynamic>{
        'device_type': deviceType, // Key matching the trigger
      };
      if (fullName != null && fullName.isNotEmpty) {
        userData['full_name'] = fullName; // Key matching the trigger
      }

      // 3. Call Supabase with metadata
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );

      if (response.user == null) {
        throw AuthFailure('Sign up failed: No user returned');
      }

      // Check if email confirmation is required
      final requiresEmailConfirmation = response.session == null;

      if (requiresEmailConfirmation) {
        AppLogger.info(
          'User signed up successfully - email confirmation required',
          data: {'userId': response.user!.id},
        );
      } else {
        // User is immediately signed in - emit to stream right away
        final appUser = AppUser.fromSupabase(response.user!);
        _userController.add(appUser);

        AppLogger.info(
          'User signed up successfully - immediately signed in',
          data: {'userId': response.user!.id},
        );
      }

      return requiresEmailConfirmation;
    } on AuthException catch (e) {
      final message = _mapAuthExceptionToMessage(e);
      AppLogger.error('Sign up failed', error: e, data: {'message': message});
      throw AuthFailure(message);
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during sign up',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Sign up failed: ${e.toString()}');
    }
  }

  /// Signs in an existing user with email and password.
  Future<void> signInWithEmail(String email, String password) async {
    // Ensure AuthService is initialized before proceeding
    await ensureInitialized();

    try {
      AppLogger.info('Signing in user with email', data: {'email': email});

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthFailure('Sign in failed: No user returned');
      }

      // Immediately emit user to stream (don't wait for onAuthStateChange)
      // This makes navigation instant
      final appUser = AppUser.fromSupabase(response.user!);
      _userController.add(appUser);

      AppLogger.info(
        'User signed in successfully',
        data: {'userId': response.user!.id},
      );
    } on AuthException catch (e) {
      final message = _mapAuthExceptionToMessage(e);
      AppLogger.error('Sign in failed', error: e, data: {'message': message});
      throw AuthFailure(message);
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during sign in',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Sign in failed: ${e.toString()}');
    }
  }

  /// Signs in a user using Google Sign-In (native flow).
  /// Uses the native Google Sign-In SDK to get tokens, then passes them to Supabase.
  Future<void> signInWithGoogle() async {
    // Ensure AuthService is initialized before proceeding
    await ensureInitialized();

    try {
      AppLogger.info('Starting Google Sign-In (native flow)');

      // 1. Initialize Google Sign-In with the serverClientId
      // CRITICAL FIX: The serverClientId must be the Web Application Client ID
      // from Google Cloud Console. This is required for iOS to exchange the token.
      final googleSignIn = GoogleSignIn(
        scopes: <String>['email', 'profile'],
        serverClientId: AppEnv.googleWebClientId,
      );

      // Sign in with Google (native flow)
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        throw AuthFailure('Google sign-in was cancelled');
      }

      // Get authentication details
      final googleAuth = await googleUser.authentication;
      // Note: The accessToken is not strictly needed by Supabase's signInWithIdToken,
      // but the ID Token is mandatory. Keeping the check robust.
      if (googleAuth.idToken == null) {
        throw AuthFailure('Failed to get Google ID token');
      }

      AppLogger.info(
        'Google Sign-In successful, exchanging ID token with Supabase',
      );

      // Sign in to Supabase using the Google ID token
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken, // Optional but good to pass
      );

      if (response.user == null) {
        throw AuthFailure('Google sign-in failed: No user returned');
      }

      // Immediately emit user to stream (don't wait for onAuthStateChange)
      // This makes navigation instant
      final appUser = AppUser.fromSupabase(response.user!);
      _userController.add(appUser);

      AppLogger.info(
        'Google Sign-In completed successfully',
        data: {'userId': response.user!.id},
      );
    } on AuthException catch (e) {
      final message = _mapAuthExceptionToMessage(e);
      AppLogger.error(
        'Google sign-in failed',
        error: e,
        data: {'message': message},
      );
      throw AuthFailure(message);
    } catch (e, stack) {
      if (e is AuthFailure) rethrow;
      AppLogger.error(
        'Unexpected error during Google sign-in',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Google sign-in failed: ${e.toString()}');
    }
  }

  /// Signs out the current user and clears the session.
  /// Also clears all local user data including documents, sync state, caches, and queues.
  Future<void> signOut() async {
    // Ensure AuthService is initialized before proceeding
    await ensureInitialized();

    try {
      AppLogger.info('Signing out user - clearing all local data');

      // Clear all local data BEFORE signing out from Supabase
      // This ensures data is cleared even if Supabase signOut fails
      try {
        AppLogger.info('Clearing document cache and Hive boxes');
        
        // Clear document Hive box
        try {
          final box = Hive.box<DocumentModel>('documents');
          await box.clear();
          AppLogger.info('Documents box cleared');
        } catch (e) {
          AppLogger.warning('Failed to clear documents box', error: e);
        }

        // Clear sync preferences box
        try {
          final syncBox = await Hive.openBox('sync_preferences');
          await syncBox.clear();
          await syncBox.close();
          AppLogger.info('Sync preferences box cleared');
        } catch (e) {
          AppLogger.warning('Failed to clear sync preferences box', error: e);
        }

        // Clear recent searches box
        try {
          final recentSearchesBox = await Hive.openBox<String>('recent_searches');
          await recentSearchesBox.clear();
          await recentSearchesBox.close();
          AppLogger.info('Recent searches box cleared');
        } catch (e) {
          AppLogger.warning('Failed to clear recent searches box', error: e);
        }

        // Clear document sync states box
        try {
          final syncStatesBox = await Hive.openBox<Map>('document_sync_states');
          await syncStatesBox.clear();
          await syncStatesBox.close();
          AppLogger.info('Document sync states box cleared');
        } catch (e) {
          AppLogger.warning('Failed to clear document sync states box', error: e);
        }

        // Clear full-text search index boxes
        try {
          final indexBox = await Hive.openBox<Map>('full_text_search_index');
          await indexBox.clear();
          await indexBox.close();
          final documentIndexBox = await Hive.openBox<Map>('document_search_index');
          await documentIndexBox.clear();
          await documentIndexBox.close();
          AppLogger.info('Full-text search index boxes cleared');
        } catch (e) {
          AppLogger.warning('Failed to clear search index boxes', error: e);
        }

        // Clear service state
        AppLogger.info('Clearing service state');
        
        // Clear document sync service
        try {
          await DocumentSyncService.instance.clearAll();
        } catch (e) {
          AppLogger.warning('Failed to clear DocumentSyncService', error: e);
        }

        // Clear document sync state service
        try {
          await DocumentSyncStateService.instance.clearAll();
        } catch (e) {
          AppLogger.warning('Failed to clear DocumentSyncStateService', error: e);
        }

        // Clear upload service
        try {
          await DocumentUploadService.instance.clearAll();
        } catch (e) {
          AppLogger.warning('Failed to clear DocumentUploadService', error: e);
        }

        // Clear download service
        try {
          await DocumentDownloadService.instance.clearAll();
        } catch (e) {
          AppLogger.warning('Failed to clear DocumentDownloadService', error: e);
        }

        // Clear search service cache
        try {
          DocumentSearchService.instance.clearCache();
        } catch (e) {
          AppLogger.warning('Failed to clear DocumentSearchService cache', error: e);
        }

        // Clear full-text search index
        try {
          await FullTextSearchIndexService.instance.clearAll();
        } catch (e) {
          AppLogger.warning('Failed to clear FullTextSearchIndexService', error: e);
        }

        // Clear recent searches
        try {
          RecentSearchesService.instance.clearRecentSearches();
        } catch (e) {
          AppLogger.warning('Failed to clear RecentSearchesService', error: e);
        }

        // Cancel background sync
        try {
          await BackgroundSyncService.cancelPeriodicSync();
          AppLogger.info('Background sync cancelled');
        } catch (e) {
          AppLogger.warning('Failed to cancel background sync', error: e);
        }

        AppLogger.info('All local data cleared successfully');
      } catch (e, stack) {
        AppLogger.error(
          'Error during data cleanup (continuing with logout)',
          error: e,
          stack: stack,
        );
        // Continue with logout even if cleanup fails
      }

      // Now sign out from Supabase
      await supabase.auth.signOut();

      // Emit null user to stream
      _userController.add(null);

      AppLogger.info('User signed out successfully');
    } on AuthException catch (e) {
      final message = _mapAuthExceptionToMessage(e);
      AppLogger.error('Sign out failed', error: e, data: {'message': message});
      throw AuthFailure(message);
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during sign out',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Sign out failed: ${e.toString()}');
    }
  }

  /// Stream of the current authenticated user.
  /// Emits `null` when the user is signed out.
  /// The stream is debounced to avoid rapid state changes.
  /// Returns a stream that emits null if not initialized, then emits user updates once initialized.
  Stream<AppUser?> get userStream {
    // Always return a stream connected to _userController
    // If not initialized, emit null initially
    // Once initialized, the auth state listener will emit to _userController
    if (!_isInitialized) {
      // Return null stream connected to controller
      // Once initialized, listener will start emitting to _userController
      return Stream<AppUser?>.value(
        null,
      ).asyncExpand((_) => _userController.stream).distinct();
    }

    // Return the current user immediately, then stream updates from controller
    final current = currentUser;
    return Stream<AppUser?>.value(
      current,
    ).asyncExpand((_) => _userController.stream).distinct();
  }

  /// Gets the current authenticated user synchronously.
  /// Returns `null` if no user is signed in or if service is not initialized.
  AppUser? get currentUser {
    if (!_isInitialized || _supabase == null) {
      return null;
    }

    try {
      final session = _supabase!.auth.currentSession;
      final user = session?.user;
      if (user != null) {
        return AppUser.fromSupabase(user);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting current user', error: e);
      return null;
    }
  }

  /// Maps Supabase [AuthException] to user-friendly error messages.
  String _mapAuthExceptionToMessage(AuthException e) {
    final message = e.message.toLowerCase();

    // Email validation errors
    if (message.contains('invalid email') || message.contains('email format')) {
      return 'Invalid email format';
    }

    // Password errors
    if (message.contains('password') && message.contains('weak')) {
      return 'Password is too weak. Please use a stronger password.';
    }
    if (message.contains('password') && message.contains('wrong')) {
      return 'Wrong password';
    }
    if (message.contains('password') && message.contains('invalid')) {
      return 'Invalid password';
    }

    // User not found
    if (message.contains('user not found') || message.contains('no user')) {
      return 'No account found with this email';
    }

    // Email already exists
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'An account with this email already exists';
    }

    // Network errors
    if (message.contains('network') ||
        message.contains('connection') ||
        message.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Rate limiting
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many requests. Please try again later.';
    }

    // Generic Supabase error - use the original message if it's user-friendly
    if (e.message.isNotEmpty) {
      return e.message;
    }

    // Fallback
    return 'Authentication failed. Please try again.';
  }

  /// Disposes the service and cleans up resources.
  void dispose() {
    _userController.close();
    _isInitialized = false;
  }
}
