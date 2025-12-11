import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/profile/presentation/screens/premium_user.dart';
import 'package:thyscan/features/profile/presentation/screens/guest_mode.dart';
import 'package:thyscan/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check auth state - show guest mode if logged out, pro mode if logged in
    final authState = ref.watch(authControllerProvider);
    
    if (authState.isAuthenticated) {
      return const ProUserProfileScreen();
    } else {
      return const ProfileGuestScreen();
    }
  }
}
