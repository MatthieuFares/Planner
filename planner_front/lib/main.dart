import 'package:flutter/material.dart';

import 'app.dart';
import 'features/auth/data/auth_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AuthSession.instance.initialize();

  runApp(const PlannerApp());
}
