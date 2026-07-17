import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hypnosis_downloads/app/view/common/assets.dart';
import 'package:hypnosis_downloads/app/view/common/colors.dart';

class AppCover extends StatelessWidget {
  const AppCover({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? DarkComponentColors.thumbnailBackgroundColor
            : Colors.grey.shade50,
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SvgPicture.asset(
          Assets.logoWithText,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
