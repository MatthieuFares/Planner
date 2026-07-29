import 'package:flutter/material.dart';

import '../../projects/presentation/projects_page.dart';
import '../data/auth_session.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;

    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        if (!session.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (session.isAuthenticated) {
          return const ProjectsPage();
        }

        return const LoginPage();
      },
    );
  }
}
