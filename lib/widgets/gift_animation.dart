import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/comment_model.dart';
import 'neon_effect.dart';

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
    HapticFeedback.mediumImpact();
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
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: [
          if (_activeBursts.isNotEmpty)
            Positioned.fill(
              child: _GiftFlashLayer(count: _activeBursts.length),
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

  const _GiftFlashLayer({required this.count});

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
        final flash = (1 - Curves.easeOut.transform(_controller.value)) * 0.22;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: flash),
                const Color(0xFFFFA726).withValues(alpha: flash * 0.55),
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1650),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.86, curve: Curves.easeOut),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.72,
    end: 1,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.24),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
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
    final topOffset = 110.0 + (widget.lane * 62.0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = math.sin(_controller.value * math.pi * 5).abs();
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GiftParticlePainter(
                  progress: _controller.value,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: topOffset,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: NeonPanel(
                      glowColor: const Color(0xFFFFB54A),
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFF17E),
                                  Color(0xFFFF8B39),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFB54A)
                                      .withValues(alpha: 0.45 + (pulse * 0.2)),
                                  blurRadius: 30,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const NeonText(
                                  'GIFT BURST',
                                  glowColor: Color(0xFFFFD65C),
                                  style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w900,
                                  ),
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
                                    fontSize: 16,
                                  ),
                                ),
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

  const _GiftParticlePainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.34);
    final fade = 1 - Curves.easeIn.transform(progress);

    final particlePaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    for (var i = 0; i < 18; i++) {
      final angle = (math.pi * 2 / 18) * i;
      final distance = 24 + (progress * 160) + ((i % 3) * 12);
      final point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      final radius = (i.isEven ? 7.0 : 4.5) * fade;
      particlePaint.color = (i % 2 == 0
              ? const Color(0xFFFFD25F)
              : const Color(0xFF5EF8FF))
          .withValues(alpha: 0.28 * fade);
      canvas.drawCircle(point, radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GiftParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
