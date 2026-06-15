import 'package:flutter/material.dart';

import '../models/comment_model.dart';
import 'neon_effect.dart';

class AnimatedCommentList extends StatelessWidget {
  final List<CommentModel> comments;
  final ValueChanged<CommentModel>? onBlockUser;
  final ValueChanged<CommentModel>? onReportComment;

  const AnimatedCommentList({
    super.key,
    required this.comments,
    this.onBlockUser,
    this.onReportComment,
  });

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Center(
        child: NeonText(
          'コメント待機中',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _AnimatedCommentTile(
          key: ValueKey(comment.id),
          comment: comment,
          isNew: index < 4,
          onBlockUser: onBlockUser,
          onReportComment: onReportComment,
        );
      },
    );
  }
}

class _AnimatedCommentTile extends StatefulWidget {
  final CommentModel comment;
  final bool isNew;
  final ValueChanged<CommentModel>? onBlockUser;
  final ValueChanged<CommentModel>? onReportComment;

  const _AnimatedCommentTile({
    super.key,
    required this.comment,
    required this.isNew,
    required this.onBlockUser,
    required this.onReportComment,
  });

  @override
  State<_AnimatedCommentTile> createState() => _AnimatedCommentTileState();
}

class _AnimatedCommentTileState extends State<_AnimatedCommentTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.18, 0),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGift = widget.comment.isGift;
    final accent = isGift ? const Color(0xFFFFA135) : const Color(0xFF00F5FF);
    final headline = isGift
        ? '${widget.comment.giftName ?? 'ギフト'} を ${widget.comment.giftCount ?? 1} 個'
        : widget.comment.text;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: NeonPanel(
              glowColor: accent,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isGift
                            ? const [
                                Color(0xFFFFE27A),
                                Color(0xFFFF8B37),
                              ]
                            : const [
                                Color(0xFF5CFFF3),
                                Color(0xFF3387FF),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.32),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isGift ? Icons.card_giftcard : Icons.chat_bubble_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.comment.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (widget.isNew)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: accent.withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.42),
                                  ),
                                ),
                                child: Text(
                                  isGift ? 'GIFT' : 'NEW',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            if (!isGift &&
                                (widget.onBlockUser != null ||
                                    widget.onReportComment != null))
                              PopupMenuButton<_CommentAction>(
                                tooltip: 'コメントメニュー',
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onSelected: (action) {
                                  switch (action) {
                                    case _CommentAction.block:
                                      widget.onBlockUser?.call(widget.comment);
                                      break;
                                    case _CommentAction.report:
                                      widget.onReportComment
                                          ?.call(widget.comment);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: _CommentAction.block,
                                    child: Text('このユーザーをブロック'),
                                  ),
                                  PopupMenuItem(
                                    value: _CommentAction.report,
                                    child: Text('このコメントを通報'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          headline,
                          style: TextStyle(
                            color: isGift
                                ? const Color(0xFFFFE7C3)
                                : Colors.white.withValues(alpha: 0.92),
                            fontSize: isGift ? 16 : 15,
                            height: 1.3,
                            fontWeight:
                                isGift ? FontWeight.w800 : FontWeight.w600,
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
    );
  }
}

enum _CommentAction {
  block,
  report,
}
