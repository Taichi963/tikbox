import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/comment_model.dart';
import 'neon_effect.dart';

const int _kHighValueGiftThreshold = 100;

class GiftAnimationOverlay extends StatefulWidget {
  final List<CommentModel> comments;
  final bool enabled;

  const GiftAnimationOverlay({
    super.key,
    required this.comments,
    this.enabled = true,
  });

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay> {
  // ギフト演出済みIDのセット。長時間使用でも上限を超えないよう管理する。
  static const int _maxSeenIds = 500;
  final Set<String> _seenGiftIds = <String>{};
  final List<CommentModel> _activeBursts = <CommentModel>[];

  @override
  void initState() {
    super.initState();
    for (final comment in widget.comments.where((c) => c.isGift)) {
      _seenGiftIds.add(comment.id);
    }
  }

  @override
  void didUpdateWidget(covariant GiftAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      return;
    }

    for (final comment in widget.comments.take(8)) {
      if (!comment.isGift || _seenGiftIds.contains(comment.id)) {
        continue;
      }
      _seenGiftIds.add(comment.id);
      // 上限を超えたら最も古いIDを削除してメモリリークを防ぐ
      if (_seenGiftIds.length > _maxSeenIds) {
        _seenGiftIds.remove(_seenGiftIds.first);
      }
      _pushGift(comment);
    }
  }

  void _pushGift(CommentModel comment) {
    setState(() {
      _activeBursts.insert(0, comment);
      if (_activeBursts.length > 3) {
        _activeBursts.removeLast();
      }
    });
  }

  void _removeGift(String id) {
    if (!mounted) {
      return;
    }
    setState(() {
      _activeBursts.removeWhere((item) => item.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasHighValueBurst = _activeBursts.any(
      (comment) => comment.giftValue >= _kHighValueGiftThreshold,
    );

    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: [
          if (_activeBursts.isNotEmpty)
            Positioned.fill(
              child: _GiftFlashLayer(
                count: _activeBursts.length,
                highlightHighValue: hasHighValueBurst,
              ),
            ),
          ..._activeBursts.asMap().entries.map((entry) {
            return Positioned.fill(
              child: _GiftBurstWidget(
                key: ValueKey(entry.value.id),
                comment: entry.value,
                lane: entry.key,
                onComplete: () => _removeGift(entry.value.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GiftFlashLayer extends StatefulWidget {
  final int count;
  final bool highlightHighValue;

  const _GiftFlashLayer({
    required this.count,
    required this.highlightHighValue,
  });

  @override
  State<_GiftFlashLayer> createState() => _GiftFlashLayerState();
}

class _GiftFlashLayerState extends State<_GiftFlashLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

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
        final flash =
            (1 - Curves.easeOut.transform(_controller.value)) *
            (widget.highlightHighValue ? 0.34 : 0.22);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                (widget.highlightHighValue
                        ? const Color(0xFFFFF3B0)
                        : Colors.white)
                    .withValues(alpha: flash),
                (widget.highlightHighValue
                        ? const Color(0xFFFF5C8A)
                        : const Color(0xFFFFA726))
                    .withValues(alpha: flash * 0.55),
                Colors.transparent,
              ],
              stops: const [0, 0.24, 1],
            ),
          ),
        );
      },
    );
  }
}

class _GiftBurstWidget extends StatefulWidget {
  final CommentModel comment;
  final int lane;
  final VoidCallback onComplete;

  const _GiftBurstWidget({
    super.key,
    required this.comment,
    required this.lane,
    required this.onComplete,
  });

  @override
  State<_GiftBurstWidget> createState() => _GiftBurstWidgetState();
}

class _GiftBurstWidgetState extends State<_GiftBurstWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  bool get _isHighValue =>
      widget.comment.giftValue >= _kHighValueGiftThreshold;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _isHighValue
          ? const Duration(milliseconds: 2200)
          : const Duration(milliseconds: 1650),
    )..forward();

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(0, _isHighValue ? 0.92 : 0.86, curve: Curves.easeOut),
    );

    _scale = Tween<double>(
      begin: _isHighValue ? 0.62 : 0.72,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: _isHighValue ? Curves.easeOutBack : Curves.elasticOut,
      ),
    );

    _slide = Tween<Offset>(
      begin: Offset(0, _isHighValue ? 0.34 : 0.24),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topOffset = _isHighValue
        ? (screenHeight * 0.22) + (widget.lane * 54.0)
        : 110.0 + (widget.lane * 62.0);
    final cardInset = _isHighValue ? 10.0 : 18.0;
    final glowColor = _isHighValue
        ? const Color(0xFFFFD95C)
        : const Color(0xFFFFB54A);
    final title = _isHighValue ? 'MEGA GIFT' : 'GIFT BURST';
    final titleGlow = _isHighValue
        ? const Color(0xFFFFF0A8)
        : const Color(0xFFFFD65C);
    final valueLabel = widget.comment.giftValue > 0
        ? 'Value ${widget.comment.giftValue}'
        : 'Special gift burst';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = math.sin(_controller.value * math.pi * 5).abs();
        return Stack(
          children: [
            if (_isHighValue)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.12),
                      radius: 0.95,
                      colors: [
                        const Color(0xFFFFD95C)
                            .withValues(alpha: 0.18 * (1 - _controller.value)),
                        const Color(0xFFFF5C8A)
                            .withValues(alpha: 0.12 * (1 - _controller.value)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _GiftParticlePainter(
                  progress: _controller.value,
                  isHighValue: _isHighValue,
                ),
              ),
            ),
            Positioned(
              left: cardInset,
              right: cardInset,
              top: topOffset,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: NeonPanel(
                      glowColor: glowColor,
                      padding: EdgeInsets.fromLTRB(
                        _isHighValue ? 22 : 18,
                        _isHighValue ? 20 : 16,
                        _isHighValue ? 22 : 18,
                        _isHighValue ? 20 : 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: _isHighValue ? 72 : 56,
                            height: _isHighValue ? 72 : 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isHighValue
                                    ? const [
                                        Color(0xFFFFF6A6),
                                        Color(0xFFFFA23F),
                                        Color(0xFFFF4F7D),
                                      ]
                                    : const [
                                        Color(0xFFFFF17E),
                                        Color(0xFFFF8B39),
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor.withValues(
                                    alpha: _isHighValue
                                        ? 0.58 + (pulse * 0.24)
                                        : 0.45 + (pulse * 0.2),
                                  ),
                                  blurRadius: _isHighValue ? 40 : 30,
                                  spreadRadius: _isHighValue ? 5 : 3,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: _isHighValue ? 38 : 30,
                            ),
                          ),
                          SizedBox(width: _isHighValue ? 18 : 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: NeonText(
                                        title,
                                        glowColor: titleGlow,
                                        style: TextStyle(
                                          fontSize: _isHighValue ? 14 : 12,
                                          letterSpacing:
                                              _isHighValue ? 2.4 : 2,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (_isHighValue)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          color: const Color(0x26FFF3B0),
                                          border: Border.all(
                                            color: const Color(0x66FFF3B0),
                                          ),
                                        ),
                                        child: const Text(
                                          'SPECIAL',
                                          style: TextStyle(
                                            color: Color(0xFFFFF3B0),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.4,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.comment.userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '${widget.comment.giftName ?? 'Gift'} x${widget.comment.giftCount ?? 1}',
                                  style: TextStyle(
                                    color: const Color(0xFFFFE7B0)
                                        .withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w800,
                                    fontSize: _isHighValue ? 18 : 16,
                                  ),
                                ),
                                if (_isHighValue) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    valueLabel,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GiftParticlePainter extends CustomPainter {
  final double progress;
  final bool isHighValue;

  const _GiftParticlePainter({
    required this.progress,
    required this.isHighValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * 0.5,
      size.height * (isHighValue ? 0.44 : 0.34),
    );
    final fade = 1 - Curves.easeIn.transform(progress);

    final particlePaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        isHighValue ? 14 : 10,
      );

    final particleCount = isHighValue ? 26 : 18;
    for (var i = 0; i < particleCount; i++) {
      final angle = (math.pi * 2 / particleCount) * i;
      final distance =
          (isHighValue ? 36 : 24) +
          (progress * (isHighValue ? 210 : 160)) +
          ((i % 3) * (isHighValue ? 16 : 12));
      final point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      final radius =
          (i.isEven ? (isHighValue ? 9.0 : 7.0) : (isHighValue ? 5.5 : 4.5)) *
          fade;
      particlePaint.color = (i % 3 == 0
              ? const Color(0xFFFFF2A8)
              : i.isEven
              ? const Color(0xFFFFD25F)
              : isHighValue
              ? const Color(0xFFFF5C8A)
              : const Color(0xFF5EF8FF))
          .withValues(alpha: (isHighValue ? 0.38 : 0.28) * fade);
      canvas.drawCircle(point, radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GiftParticlePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isHighValue != isHighValue;
  }
}
