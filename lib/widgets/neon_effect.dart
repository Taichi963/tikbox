import 'package:flutter/material.dart';

class NeonPanel extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const NeonPanel({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF00F5FF),
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          colors: [
            Color(0xCC12142B),
            Color(0xCC191C38),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: glowColor.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.22),
            blurRadius: 26,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class NeonText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color glowColor;
  final TextAlign? textAlign;

  const NeonText(
    this.text, {
    super.key,
    this.style,
    this.glowColor = const Color(0xFF7CFFDA),
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ) ??
        const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        );

    return Text(
      text,
      textAlign: textAlign,
      style: baseStyle.copyWith(
        shadows: [
          Shadow(
            color: glowColor.withValues(alpha: 0.9),
            blurRadius: 18,
          ),
          Shadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: 34,
          ),
        ],
      ),
    );
  }
}

class LiveGlowDot extends StatefulWidget {
  final Color color;
  final double size;

  const LiveGlowDot({
    super.key,
    this.color = const Color(0xFFFF315F),
    this.size = 12,
  });

  @override
  State<LiveGlowDot> createState() => _LiveGlowDotState();
}

class _LiveGlowDotState extends State<LiveGlowDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 0.88 + (t * 0.28);
        final alpha = 0.35 + (t * 0.45);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: alpha),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
