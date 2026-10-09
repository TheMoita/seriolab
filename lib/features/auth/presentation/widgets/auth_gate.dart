import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main/presentation/screens/main_screen.dart';
import '../providers/auth_providers.dart';
import '../screens/login_screen.dart';

/// Entry gateway directing authenticated users to [MainScreen],
/// or unauthenticated users to [LoginScreen]. Registration/login is strictly mandatory.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (authState.isAuthenticated) {
      return const MainScreen();
    }

    return const LoginScreen();
  }
}
