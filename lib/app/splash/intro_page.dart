import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hypnosis_downloads/app/splash/privacy_policy.dart';
import 'package:hypnosis_downloads/app/view/common/assets.dart';
import 'package:hypnosis_downloads/app/view/common/colors.dart';
import 'package:hypnosis_downloads/app/view/components/app_logo.dart';
import 'package:hypnosis_downloads/app/view/widgets/default_buttons.dart';
import 'package:hypnosis_downloads/authentication/login_with_email_password/view/login_page.dart';
import 'package:hypnosis_downloads/authentication/register/view/register_page.dart';
import 'package:video_player/video_player.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  static Page<void> get page => const MaterialPage<void>(child: IntroPage());

  static MaterialPageRoute<dynamic> get route =>
      MaterialPageRoute(builder: (context) => const IntroPage());

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: IntroView(),
    );
  }
}

class IntroView extends StatelessWidget {
  const IntroView({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;

    return ColoredBox(
      color: ComponentColors.backgroundColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset > 0 ? 8 : 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (bottomInset > 0 ? 16 : 24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 40,
                      child: AppLogoWithText(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Try a full Uncommon\nHypnosis session FREE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.15,
                        color: ComponentColors.secondaryHeadlineTextColor,
                      ),
                    ),
                    const SizedBox(height: 0),
                    const IntroVideoWidget(),
                    const SizedBox(height: 0),
                    const Text(
                      "Get the 'First Time Hypnosis' session\nfree (usually \$14.95) when you\ncreate your free account.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: ComponentColors.defaultBodyTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      'Create my free account',
                      onTap: () => Navigator.of(context).push(RegisterPage.route),
                    ),
                    const SizedBox(height: 20),
                    _LoginLinkText(
                      onLoginTap: () => Navigator.of(context).pushReplacement(
                        PageRouteBuilder<void>(
                          transitionDuration: const Duration(milliseconds: 800),
                          pageBuilder: (_, __, ___) => const LoginPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '©2026 Uncommon Knowledge Ltd, Boswell House, Argyll Square, Oban,\nUK PA34 4BD. Registered Company 03573107',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: ComponentColors.defaultLabelTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).push(PrivacyPolicyPage.route),
                      style: TextButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 16,
                          color: ComponentColors.defaultTextButtonColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginLinkText extends StatelessWidget {
  const _LoginLinkText({
    required this.onLoginTap,
  });

  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          color: ComponentColors.defaultBodyTextColor,
        ),
        children: [
          const TextSpan(text: 'Already got an account? '),
          TextSpan(
            text: 'Login here',
            style: const TextStyle(
              color: ComponentColors.linkColor,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()..onTap = onLoginTap,
          ),
        ],
      ),
    );
  }
}

class IntroVideoWidget extends StatefulWidget {
  const IntroVideoWidget({super.key});

  @override
  State<IntroVideoWidget> createState() => _IntroVideoWidgetState();
}

class _IntroVideoWidgetState extends State<IntroVideoWidget> {
  static const _introVideoAsset = 'assets/videos/splash_mark.mp4';

  late VideoPlayerController _controller;
  bool _initialized = false;

  bool visiblePlaceholder = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(_introVideoAsset)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
      });
  }

  @override
  void deactivate() {
    // Pauses video while navigating to next page.
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 32;
    // Fall back to a square box until the video reports its real aspect ratio.
    final aspectRatio =
        _initialized && _controller.value.aspectRatio > 0
            ? _controller.value.aspectRatio
            : 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: _initialized
                  ? VideoPlayer(_controller)
                  : const ColoredBox(color: Colors.black),
            ),
          ),
          SizedBox.square(
            dimension: width,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: visiblePlaceholder ? _buildPlaceholder() : null,
            ),
          ),
        ],
      ),
    );
  }

  _buildPlaceholder() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          Assets.youtubeImagePlaceholder,
          fit: BoxFit.contain,
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            _controller.play();
            setState(() {
              visiblePlaceholder = false;
            });
          },
          child: SizedBox.square(
            dimension: 64,
            child: SvgPicture.asset(
              IconsBold.play,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        )
      ],
    );
  }
}
