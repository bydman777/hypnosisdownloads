import 'package:flutter/material.dart';
import 'package:hypnosis_downloads/app/view/common/colors.dart';
import 'package:hypnosis_downloads/app/view/components/text/body_medium_text.dart';
import 'package:hypnosis_downloads/app/view/widgets/default_buttons.dart';

/// Safety message shown when hypnosis playback starts.
const String skipIntroWarningMessage =
    'Do not listen to hypnosis whenever you need to maintain concentration, '
    'such as when driving.';

/// Shows the mandatory driving-safety warning.
///
/// The dialog overlays the screen and cannot be dismissed by tapping outside;
/// the user must tap "OK" to continue. Resolves to `true` once acknowledged,
/// or `false` if it is dismissed some other way (e.g. back button).
Future<bool> showDrivingSafetyWarning(BuildContext context) async {
  final acknowledged = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: ComponentColors.primaryCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: const BodyMediumText(skipIntroWarningMessage),
        actions: [
          PrimaryButton(
            'OK',
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
  return acknowledged ?? false;
}
