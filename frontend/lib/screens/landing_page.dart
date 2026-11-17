
import 'package:flutter/material.dart';
import '../auth/auth_screen.dart';
import '../theme/theme_controller.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();

  final Map<String, GlobalKey> _sectionKeys = {
    'HOME': GlobalKey(),
    'ABOUT US': GlobalKey(),
    'OUR SERVICES': GlobalKey(),
    'HOW IT WORKS': GlobalKey(),
    'FAQs': GlobalKey(),
    'CONTACT US': GlobalKey(),
  };

  String _activeSection = 'HOME';

  final List<String> _navigationItems = const [
    'HOME',
    'ABOUT US',
    'OUR SERVICES',
    'HOW IT WORKS',
    'FAQs',
    'CONTACT US',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateActiveSection);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateActiveSection);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateActiveSection() {
    String currentSection = 'HOME';

    for (final item in _navigationItems) {
      final sectionContext = _sectionKeys[item]?.currentContext;
      if (sectionContext == null) continue;

      final renderObject = sectionContext.findRenderObject();

      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }

      final position = renderObject.localToGlobal(Offset.zero);

      if (position.dy <= 160) {
        currentSection = item;
      }
    }

    if (currentSection != _activeSection && mounted) {
      setState(() {
        _activeSection = currentSection;
      });
    }
  }

  Future<void> _scrollToSection(String section) async {
    final sectionContext = _sectionKeys[section]?.currentContext;

    if (sectionContext == null) return;

    setState(() {
      _activeSection = section;
    });

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeInOutCubic,
      alignment: 0,
    );
  }

  void _openAuth(BuildContext context, {required String role}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(initialRole: role),
      ),
    );
  }

  Widget _section({
    required String navigationName,
    required Widget child,
    bool animate = true,
  }) {
    return Container(
      key: _sectionKeys[navigationName],
      child: animate
          ? _RevealOnScroll(
              scrollController: _scrollController,
              child: child,
            )
          : child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            _header(context),
            _navigation(context),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    _section(
                      navigationName: 'HOME',
                      child: _hero(context),
                    ),
                    _section(
                      navigationName: 'ABOUT US',
                      child: _about(context),
                    ),
                    _section(
                      navigationName: 'OUR SERVICES',
                      child: _services(context),
                    ),
                    _section(
                      navigationName: 'HOW IT WORKS',
                      child: _howItWorks(context),
                    ),
                    _section(
                      navigationName: 'FAQs',
                      child: _faqs(context),
                    ),
                    _section(
                      navigationName: 'CONTACT US',
                      child: _contactUs(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HEADER

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        Widget themeButton() {
          return AnimatedBuilder(
            animation: ThemeController.instance,
            builder: (context, child) {
              final isDark =
                  Theme.of(context).brightness == Brightness.dark;

              return IconButton(
                tooltip: isDark ? 'Light mode' : 'Dark mode',
                onPressed: () {
                  ThemeController.instance.setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
                icon: Icon(
                  isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: colors.primary,
                ),
              );
            },
          );
        }

        Widget logo() {
          return Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite,
                  color: colors.primary,
                  size: isMobile ? 27 : 34,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'MzaziCare',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 27,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget loginButton() {
          return TextButton(
            onPressed: () => _openAuth(context, role: 'client'),
            child: Text(
              'LOGIN',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
          );
        }

        Widget signupButton() {
          return ElevatedButton(
            onPressed: () => _openAuth(context, role: 'client'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 17 : 22,
                vertical: isMobile ? 11 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: Text(
              'SIGN UP',
              style: TextStyle(fontSize: isMobile ? 11 : 13),
            ),
          );
        }

        if (isMobile) {
          return Container(
            width: double.infinity,
            color: colors.surface,
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    logo(),
                    const Spacer(),
                    themeButton(),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    loginButton(),
                    const SizedBox(width: 8),
                    signupButton(),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          color: colors.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: 35,
            vertical: 18,
          ),
          child: Row(
            children: [
              logo(),
              const Spacer(),
              themeButton(),
              const SizedBox(width: 8),
              loginButton(),
              const SizedBox(width: 8),
              signupButton(),
            ],
          ),
        );
      },
    );
  }

  // NAVIGATION

  Widget _navigation(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _navigationItems.map((item) {
            final isActive = _activeSection == item;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: TextButton(
                onPressed: () => _scrollToSection(item),
                style: TextButton.styleFrom(
                  foregroundColor:
                      isActive ? colors.primary : colors.onSurface,
                  backgroundColor: isActive
                      ? colors.secondaryContainer
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.7,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // HOME / HERO

  Widget _hero(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 22 : 35,
            vertical: isMobile ? 55 : 90,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface,
                colors.secondaryContainer,
                colors.surface,
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: colors.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: colors.primary,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'PERSONALISED ELDERLY HOME CARE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: isMobile ? 9 : 11,
                          letterSpacing: isMobile ? 0.7 : 1.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 35 : 30),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Text(
                  'Professional Caregivers for Your Loved Ones',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: isMobile ? 34 : 43,
                    height: 1.2,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.1,
                  ),
                ),
              ),

              SizedBox(height: isMobile ? 20 : 22),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  'Find trusted caregivers for elderly care, companionship, '
                  'health monitoring and daily assistance at home. '
                  'Because your loved ones deserve compassionate care.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: isMobile ? 15 : 17,
                    height: 1.8,
                  ),
                ),
              ),

              SizedBox(height: isMobile ? 28 : 35),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        _openAuth(context, role: 'client'),
                    icon: const Icon(Icons.search, size: 19),
                    label: const Text('FIND A CAREGIVER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 22 : 27,
                        vertical: isMobile ? 17 : 21,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(35),
                      ),
                      elevation: 3,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _openAuth(context, role: 'caregiver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(
                        color: colors.primary,
                        width: 1.5,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 18 : 27,
                        vertical: isMobile ? 17 : 21,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(35),
                      ),
                    ),
                    child: const Text(
                      'BECOME A CAREGIVER',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isMobile ? 32 : 45),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: isMobile ? 17 : 35,
                runSpacing: 15,
                children: const [
                  _HeroBenefit(
                    icon: Icons.verified_outlined,
                    label: 'Verified profiles',
                  ),
                  _HeroBenefit(
                    icon: Icons.favorite_border,
                    label: 'Personalised care',
                  ),
                  _HeroBenefit(
                    icon: Icons.support_agent,
                    label: 'Family support',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ABOUT US

  Widget _about(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 30,
        vertical: isMobile ? 50 : 70,
      ),
      child: Column(
        children: [
          Text(
            'ABOUT MZAZICARE',
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Caring for Those Who Once Cared for Us',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: isMobile ? 25 : 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Text(
              'MzaziCare is a platform designed to connect families '
              'with trusted caregivers who provide personalised elderly '
              'home care. We make it easier for families to discover '
              'caregivers, arrange visits and stay informed about the '
              'wellbeing of their loved ones.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 15,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // OUR SERVICES

  Widget _services(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final services = [
      (
        Icons.elderly,
        'Elderly Care',
        'Personalised daily assistance and support for older adults.',
      ),
      (
        Icons.favorite_outline,
        'Companionship',
        'Meaningful interaction, emotional support and engagement.',
      ),
      (
        Icons.health_and_safety_outlined,
        'Health Monitoring',
        'Support with daily health routines and wellbeing.',
      ),
      (
        Icons.home_outlined,
        'Home Assistance',
        'Help with everyday household activities and comfort.',
      ),
    ];

    return Container(
      color: colors.surfaceContainerLow,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 30,
        vertical: isMobile ? 50 : 65,
      ),
      child: Column(
        children: [
          Text(
            'WHAT WE OFFER',
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Our Home Care Services',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 26 : 30,
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 800 ? 2 : 1;
              final width = columns == 2
                  ? (constraints.maxWidth - 15) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 15,
                runSpacing: 15,
                children: services.map((service) {
                  return SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: colors.outlineVariant,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              service.$1,
                              color: colors.primary,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.$2,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  service.$3,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    height: 1.5,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // HOW IT WORKS

  Widget _howItWorks(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final steps = [
      (
        '01',
        'Create an Account',
        'Register as a family member or caregiver.',
      ),
      (
        '02',
        'Share Your Care Needs',
        'Tell us about the care and assistance required.',
      ),
      (
        '03',
        'Discover Caregivers',
        'Explore suitable caregiver recommendations.',
      ),
      (
        '04',
        'Arrange Care',
        'Connect with caregivers and organise visits.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 30,
        vertical: isMobile ? 50 : 70,
      ),
      child: Column(
        children: [
          Text(
            'SIMPLE AND CONVENIENT',
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'How MzaziCare Works',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: isMobile ? 26 : 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 35),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 30,
            children: steps.map((step) {
              return SizedBox(
                width: isMobile ? 145 : 230,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colors.secondaryContainer,
                      child: Text(
                        step.$1,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      step.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      step.$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // FAQS

  Widget _faqs(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final questions = [
      (
        'What is MzaziCare?',
        'MzaziCare is a platform that connects families with caregivers '
            'for personalised elderly home care and assistance.',
      ),
      (
        'How do I find a caregiver?',
        'Create a family account, provide the care recipient’s needs '
            'and explore caregiver recommendations available on the platform.',
      ),
      (
        'Are caregivers verified?',
        'Caregiver profiles are subject to administrator verification '
            'before they are presented as verified on the platform.',
      ),
      (
        'Can I communicate with a caregiver?',
        'Yes. Families and caregivers can communicate through the '
            'in-app messaging feature when a conversation is available.',
      ),
      (
        'Can caregivers apply to join MzaziCare?',
        'Yes. Select Become a Caregiver and register using the caregiver '
            'option. You can then complete your caregiver profile.',
      ),
      (
        'Can I manage scheduled care visits?',
        'Families can view their care arrangements and booking statuses '
            'through their account.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: colors.surfaceContainerLow,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 30,
        vertical: isMobile ? 50 : 70,
      ),
      child: Column(
        children: [
          Text(
            'HAVE QUESTIONS?',
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Frequently Asked Questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: isMobile ? 25 : 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          ...questions.map((question) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(13),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: colors.outlineVariant,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      iconColor: colors.primary,
                      collapsedIconColor: colors.primary,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      title: Text(
                        question.$1,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        18,
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            question.$2,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              height: 1.6,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // CONTACT US

  Widget _contactUs(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final features = [
      (
        Icons.verified_user_outlined,
        'Verified Caregivers',
        'Caregiver profiles are subject to administrator verification.',
      ),
      (
        Icons.psychology_outlined,
        'Intelligent Matching',
        'Explainable recommendations help families understand caregiver matches.',
      ),
      (
        Icons.calendar_month_outlined,
        'Easy Scheduling',
        'Manage care arrangements and scheduled visits.',
      ),
      (
        Icons.chat_bubble_outline,
        'Family Communication',
        'Stay connected through messages and care updates.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 30,
        vertical: isMobile ? 50 : 70,
      ),
      child: Column(
        children: [
          Text(
            'WE ARE HERE TO HELP',
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Contact Us',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: isMobile ? 27 : 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Text(
              'Have questions about finding care or joining our caregiver '
              'community? Sign in or create an account to get started '
              'with MzaziCare.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 25),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    _openAuth(context, role: 'client'),
                icon: const Icon(Icons.person_outline),
                label: const Text('FAMILY ACCOUNT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _openAuth(context, role: 'caregiver'),
                icon: const Icon(
                  Icons.volunteer_activism_outlined,
                ),
                label: const Text('CAREGIVER ACCOUNT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 45 : 65),
          Divider(color: colors.outline),
          SizedBox(height: isMobile ? 35 : 50),

          Text(
            'THE MZAZICARE DIFFERENCE',
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Why Choose MzaziCare?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 26 : 30,
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),

          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 800
                  ? (constraints.maxWidth - 15) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 15,
                runSpacing: 15,
                children: features.map((feature) {
                  return SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: colors.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              feature.$1,
                              color: colors.primary,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  feature.$2,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  feature.$3,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    height: 1.5,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          SizedBox(height: isMobile ? 40 : 60),

          // FINAL CALL TO ACTION

          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 25,
              vertical: isMobile ? 35 : 45,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  colors.primaryContainer,
                ],
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite,
                  color: colors.onPrimary,
                  size: 38,
                ),
                const SizedBox(height: 18),
                Text(
                  'Your Loved Ones Deserve the Best Care',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: isMobile ? 24 : 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'Take the first step towards personalised home care. '
                  'Find trusted caregivers and give your loved ones '
                  'the compassionate support they deserve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () =>
                      _openAuth(context, role: 'client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 17,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'GET STARTED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SECTION REVEAL ANIMATION

class _RevealOnScroll extends StatefulWidget {
  const _RevealOnScroll({
    required this.scrollController,
    required this.child,
  });

  final ScrollController scrollController;
  final Widget child;

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    widget.scrollController.addListener(_checkVisibility);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  @override
  void didUpdateWidget(covariant _RevealOnScroll oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_checkVisibility);
      widget.scrollController.addListener(_checkVisibility);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkVisibility();
      });
    }
  }

  void _checkVisibility() {
    if (_hasAnimated || !mounted) return;

    final renderObject = context.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final position = renderObject.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

    final isVisible = position.dy < screenHeight * 0.88 &&
        position.dy + renderObject.size.height > 0;

    if (isVisible) {
      _hasAnimated = true;
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_checkVisibility);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// HERO BENEFIT ITEM

class _HeroBenefit extends StatelessWidget {
  const _HeroBenefit({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: colors.primary,
          size: 18,
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
