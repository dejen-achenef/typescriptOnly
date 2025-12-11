import 'package:flutter/material.dart';

class HelpArticleScanCropScreen extends StatefulWidget {
  const HelpArticleScanCropScreen({
    super.key,
    this.title = 'How to Scan & Crop',
  });
  final String title;

  @override
  State<HelpArticleScanCropScreen> createState() =>
      _HelpArticleScanCropScreenState();
}

class _HelpArticleScanCropScreenState extends State<HelpArticleScanCropScreen> {
  final ScrollController _scrollController = ScrollController();

  // Keys for sections (used by Table of Contents)
  final List<GlobalKey> _sectionKeys = List.generate(3, (_) => GlobalKey());

  bool _tocExpanded = true;
  int? _helpful; // 1 = yes, 0 = no

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToSection(int index) async {
    final ctx = _sectionKeys[index].currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.05, // leave a little space above the header
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: t.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text(
          widget.title,
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () {
              /* TODO: bookmark */
            },
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
          IconButton(
            onPressed: () {
              /* TODO: share */
            },
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive padding + max content width
            final double hPad = (constraints.maxWidth * 0.07).clamp(16.0, 24.0);
            return Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  12,
                  hPad,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table of Contents (collapsible)
                      _TOCHeader(
                        expanded: _tocExpanded,
                        onTap: () =>
                            setState(() => _tocExpanded = !_tocExpanded),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _tocExpanded
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: _TOCList(
                          items: const [
                            '1. Capturing Your Document',
                            '2. Automatic & Manual Cropping',
                            '3. Fine‑Tuning the Crop',
                          ],
                          onTap: (i) => _scrollToSection(i),
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),

                      // Intro paragraph
                      Text(
                        "Learn the best practices for capturing clear scans, and how to use our smart cropping tools to perfectly frame your documents. "
                        "Follow these steps for a perfect scan every time.",
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: t.textTheme.bodyMedium?.color?.withOpacity(
                            0.9,
                          ),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 1
                      _SectionHeader(
                        key: _sectionKeys[0],
                        text: '1. Capturing Your Document',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Place your document on a flat, well‑lit surface with good contrast. Tap the camera button to capture. "
                        "Our app will automatically detect the edges.",
                        style: t.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 12),

                      _IllustrationCard(),
                      const SizedBox(height: 12),

                      _TipCard(
                        icon: Icons.lightbulb_outline_rounded,
                        bg: Color.alphaBlend(
                          cs.primary.withOpacity(0.10),
                          cs.surface,
                        ),
                        border: cs.primary.withOpacity(0.20),
                        text:
                            "Tip: For best results, avoid shadows and ensure the document is flat. "
                            "Natural daylight works wonders for clarity!",
                      ),

                      const SizedBox(height: 20),

                      // Section 2
                      _SectionHeader(
                        key: _sectionKeys[1],
                        text: '2. Automatic & Manual Cropping',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "After capturing, the app will suggest a crop. If it’s perfect, tap ‘Continue’. "
                        "If you need to adjust it, you can switch to manual mode.",
                        style: t.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 16),

                      // Section 3
                      _SectionHeader(
                        key: _sectionKeys[2],
                        text: '3. Fine‑Tuning the Crop',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "In manual mode, drag the corners of the crop box to precisely match your document’s edges. "
                        "A magnifying loupe will appear to help you with accuracy.",
                        style: t.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 12),

                      _WarningCard(
                        icon: Icons.warning_amber_rounded,
                        bg: Color.alphaBlend(
                          Colors.amber.withOpacity(0.10),
                          cs.surface,
                        ),
                        border: Colors.amber.withOpacity(0.25),
                        text:
                            "Warning: Over‑cropping can cut off important information. "
                            "Always double‑check your selection before saving the scan.",
                      ),

                      const SizedBox(height: 20),

                      // Helpful prompt
                      Center(
                        child: Text(
                          "Was this helpful?",
                          style: t.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FeedbackChip(
                            label: 'Yes',
                            icon: Icons.thumb_up_alt_outlined,
                            selected: _helpful == 1,
                            onTap: () => setState(() => _helpful = 1),
                          ),
                          const SizedBox(width: 12),
                          _FeedbackChip(
                            label: 'No',
                            icon: Icons.thumb_down_alt_outlined,
                            selected: _helpful == 0,
                            onTap: () => setState(() => _helpful = 0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Still need help?
                      Center(
                        child: Text(
                          "Still need help?",
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.textTheme.bodyMedium?.color?.withOpacity(
                              0.7,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            /* TODO: contact */
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Contact Support',
                            style: t.textTheme.titleSmall?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Related Articles
                      const _SectionTitle('Related Articles'),
                      const SizedBox(height: 10),
                      _RelatedTile(title: 'Enhancing Your Scans with Filters'),
                      const SizedBox(height: 10),
                      _RelatedTile(title: 'Exporting as PDF or JPG'),
                      const SizedBox(height: 10),
                      _RelatedTile(title: 'Organizing Documents into Folders'),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/* ---------------------------- UI Pieces ---------------------------- */

class _TOCHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _TOCHeader({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Table of Contents',
                style: t.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: t.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _TOCList extends StatelessWidget {
  final List<String> items;
  final ValueChanged<int> onTap;
  const _TOCList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final isLast = i == items.length - 1;
          return InkWell(
            onTap: () => onTap(i),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: isLast
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      )
                    : null,
                border: Border(
                  bottom: BorderSide(
                    color: isLast
                        ? Colors.transparent
                        : cs.outline.withOpacity(0.06),
                    width: 1,
                  ),
                ),
              ),
              child: Text(items[i], style: t.textTheme.bodyMedium),
            ),
          );
        }),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Text(
      text,
      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    // Card with soft gradient and a stylized doc illustration (no external assets)
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.12), cs.primary.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              t.brightness == Brightness.dark ? 0.25 : 0.08,
            ),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: -0.05,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: t.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: cs.outline.withOpacity(0.15)),
            ),
            child: Icon(
              Icons.description_rounded,
              size: 48,
              color: t.textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color border;
  final String text;
  const _TipCard({
    required this.icon,
    required this.bg,
    required this.border,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: t.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color border;
  final String text;
  const _WarningCard({
    required this.icon,
    required this.bg,
    required this.border,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: t.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FeedbackChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? cs.onPrimary : t.textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: t.textTheme.bodyMedium?.copyWith(
                color: selected ? cs.onPrimary : t.textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  final String title;
  const _RelatedTile({required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              t.brightness == Brightness.dark ? 0.22 : 0.06,
            ),
            blurRadius: 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: t.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: t.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------- Section Title ---------------------------- */

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Text(
      text,
      style: t.textTheme.labelMedium?.copyWith(
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: t.colorScheme.onSurface.withOpacity(0.65),
      ),
    );
  }
}
