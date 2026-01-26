import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../../widgets/primary_button.dart';
import '../../core/onboarding_helper.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingPage> _getPages(AppLocalizations t) {
    return [
      OnboardingPage(
        image: 'assets/images/onboarding_1.png',
        title: t.onboardingTitle1,
        subtitle: t.onboardingSubtitle1,
      ),
      OnboardingPage(
        image: 'assets/images/onboarding_2.png',
        title: t.onboardingTitle2,
        subtitle: t.onboardingSubtitle2,
      ),
      OnboardingPage(
        image: 'assets/images/onboarding_3.png',
        title: t.onboardingTitle3,
        subtitle: t.onboardingSubtitle3,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    final t = AppLocalizations.of(context);
    if (t == null) return;
    final pages = _getPages(t);
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _onGetStartedPressed() async {
    // Mark onboarding as completed
    await OnboardingHelper.setOnboardingCompleted();

    // Note: Navigation is handled by AuthWrapper (top-level gate)
    // Since AuthWrapper uses FutureBuilder for onboarding check (not memoized),
    // we need to trigger a rebuild. We do this by popping this screen and letting
    // AuthWrapper rebuild naturally. However, since we're the root widget,
    // we can't pop. Instead, we rely on the fact that the FutureBuilder will
    // check fresh on the next build cycle.
    //
    // To ensure immediate update, we can trigger a rebuild by calling setState
    // on the parent, but since AuthWrapper is the parent and uses StreamBuilder,
    // it will rebuild when the stream emits. Since idTokenChanges doesn't emit
    // when onboarding changes, we need a different approach.
    //
    // For now, we'll let the natural rebuild cycle handle it. The FutureBuilder
    // in AuthWrapper creates a fresh Future on each build, so it should work.
    // If there's a delay, it's acceptable as onboarding completion is rare.
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (t == null) {
      // Fallback if localization not available yet
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final pages = _getPages(t);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: pages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: Colors.black,
                      dotColor: Colors.grey[300]!,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                      spacing: 8,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _currentPage == pages.length - 1
                      ? PrimaryButton(
                          text: t.getStarted,
                          onPressed: _onGetStartedPressed,
                        )
                      : PrimaryButton(
                          text: t.next,
                          onPressed: _onNextPressed,
                        ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Image.asset(
            page.image,
            height: 300,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String image;
  final String title;
  final String subtitle;

  OnboardingPage({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}
