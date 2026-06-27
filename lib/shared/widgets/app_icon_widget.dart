import 'package:flutter/material.dart';

/// NexSkills Hub app icon — exact PNG asset, no modifications.
class AppIconWidget extends StatelessWidget {
  final double size;
  const AppIconWidget({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
