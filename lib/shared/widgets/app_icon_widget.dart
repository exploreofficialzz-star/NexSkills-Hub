import 'package:flutter/material.dart';

/// NexSkills Hub app icon displayed inside the app.
/// Uses the exact PNG asset as uploaded — no modifications.
/// For launcher icon: run `flutter pub run flutter_launcher_icons` after adding files.
class AppIconWidget extends StatelessWidget {
  final double size;
  const AppIconWidget({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
