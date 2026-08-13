import 'package:flutter/material.dart';

import '../widgets/mysumber_leaf_logo.dart';
import 'login_screen.dart';

const _pageBackground = RadialGradient(
  center: Alignment(0, -0.55),
  radius: 1.3,
  colors: [Color(0xFFFDFEFC), Color(0xFFEFF1ED)],
);

const _continueGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF6EE7A0), Color(0xFF16A34A)],
);

const _adminGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4FA895), Color(0xFF14524A)],
);

const _workerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7CC2F7), Color(0xFF1D5FC7)],
);

const _customerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF6EE68B), Color(0xFF1CA94C)],
);

/// Two-page welcome + role-select flow. Continue/Back drive it for new
/// users; the underlying PageView also accepts a direct swipe for anyone
/// who's been through it before.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _pick(String role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginScreen(intendedRole: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final isPhoneLandscape =
        viewport.shortestSide < 600 && viewport.width > viewport.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _pageBackground),
        child: SafeArea(
          child: isPhoneLandscape
              ? _LandscapeLanding(onPick: _pick)
              : Stack(
                  children: [
                    PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [
                        _WelcomePage(onContinue: () => _goTo(1)),
                        _RoleSelectPage(
                          onBack: () => _goTo(0),
                          onPick: _pick,
                        ),
                      ],
                    ),
                    // Pinned outside the PageView so it reflects the current
                    // page instead of swiping away with the page content.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      child: _PageDots(page: _page),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int page;
  const _PageDots({required this.page});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i == page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF22C55E) : const Color(0xFFC9CCC7),
          ),
        );
      }),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onContinue;
  const _WelcomePage({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        children: [
          const Spacer(flex: 5),
          const MySumberLeafLogo(size: 150),
          const SizedBox(height: 18),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [Color(0xFF34D399), Color(0xFF15803D)],
            ).createShader(rect),
            child: const Text(
              'MySumber',
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Monitor your energy grid',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: Color(0xFF8A8F87),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Text(
            'from your phone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: Color(0xFF22A559),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(flex: 6),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onContinue,
              child: Container(
                width: double.infinity,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _continueGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14301F),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _RoleSelectPage extends StatelessWidget {
  final VoidCallback onBack;
  final ValueChanged<String> onPick;
  const _RoleSelectPage({
    required this.onBack,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, color: Color(0xFF9AA098)),
                  Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF9AA098),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 3),
          const Text(
            'Continue as:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              color: Color(0xFF7D827A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 16.0;
              final square = (constraints.maxWidth - gap) / 2;
              return Column(
                children: [
                  Row(
                    children: [
                      _RoleCard(
                        width: square,
                        height: square,
                        wide: false,
                        label: 'Administrator',
                        gradient: _adminGradient,
                        icon: const _AdminIcon(),
                        onTap: () => onPick('admin'),
                      ),
                      const SizedBox(width: gap),
                      _RoleCard(
                        width: square,
                        height: square,
                        wide: false,
                        label: 'Worker',
                        gradient: _workerGradient,
                        icon: const Icon(Icons.engineering,
                            color: Colors.white, size: 46),
                        onTap: () => onPick('worker'),
                      ),
                    ],
                  ),
                  const SizedBox(height: gap),
                  _RoleCard(
                    width: constraints.maxWidth,
                    height: square,
                    wide: true,
                    label: 'Customer',
                    gradient: _customerGradient,
                    icon: const Icon(Icons.person,
                        color: Colors.white, size: 64),
                    onTap: () => onPick('user'),
                  ),
                ],
              );
            },
          ),
          const Spacer(flex: 5),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _AdminIcon extends StatelessWidget {
  const _AdminIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 4,
            top: 8,
            child: Icon(Icons.person, color: Colors.white, size: 42),
          ),
          Positioned(
            right: 0,
            top: -2,
            child: Icon(Icons.star,
                color: Colors.white.withValues(alpha: 0.95), size: 20),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final double width;
  final double height;
  final bool wide;
  final String label;
  final Gradient gradient;
  final Widget icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.width,
    required this.height,
    required this.wide,
    required this.label,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: wide
              ? Stack(
                  children: [
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(child: icon),
                    ),
                    Positioned(
                      left: 4,
                      bottom: 0,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Center(child: icon)),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Phone-landscape fallback: both "pages" side by side in one screen since
/// there's enough width for it and swiping a two-page flow feels awkward
/// sideways. No landscape mockup was supplied, so this reuses the same
/// palette/icon language rather than matching a spec.
class _LandscapeLanding extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _LandscapeLanding({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MySumberLeafLogo(size: 84),
                const SizedBox(height: 10),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF15803D)],
                  ).createShader(rect),
                  child: const Text(
                    'MySumber',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Monitor your energy grid\nfrom your phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8A8F87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final square = (constraints.maxWidth - gap) / 2;
                final cardHeight = square * 0.85;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        _RoleCard(
                          width: square,
                          height: cardHeight,
                          wide: false,
                          label: 'Administrator',
                          gradient: _adminGradient,
                          icon: const _AdminIcon(),
                          onTap: () => onPick('admin'),
                        ),
                        const SizedBox(width: gap),
                        _RoleCard(
                          width: square,
                          height: cardHeight,
                          wide: false,
                          label: 'Worker',
                          gradient: _workerGradient,
                          icon: const Icon(Icons.engineering,
                              color: Colors.white, size: 34),
                          onTap: () => onPick('worker'),
                        ),
                      ],
                    ),
                    const SizedBox(height: gap),
                    _RoleCard(
                      width: constraints.maxWidth,
                      height: cardHeight,
                      wide: true,
                      label: 'Customer',
                      gradient: _customerGradient,
                      icon: const Icon(Icons.person,
                          color: Colors.white, size: 46),
                      onTap: () => onPick('user'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
