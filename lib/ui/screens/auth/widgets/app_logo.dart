import 'package:flutter/material.dart';
import 'package:flutterquiz/commons/commons.dart' show QImage;
import 'package:flutterquiz/core/constants/assets_constants.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: const ClipOval(
          child: QImage(
            imageUrl: Assets.appLogo,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
