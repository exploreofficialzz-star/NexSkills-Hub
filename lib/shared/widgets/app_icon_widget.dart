import 'package:flutter/material.dart';

/// NexSkills Hub app icon.
/// Displays the exact PNG asset — no white, no background, no clipping.
/// The icon's transparent areas let the parent background show through.
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
