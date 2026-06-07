import 'package:flutter/material.dart';

import '../models/reader_models.dart';

enum ShortcutTooltipPlacement { defaultPosition, right }

class ShortcutTooltip extends StatelessWidget {
  const ShortcutTooltip({
    required this.label,
    required this.child,
    this.shortcut,
    this.placement = ShortcutTooltipPlacement.defaultPosition,
    this.sideGap = 8,
    super.key,
  });

  final String label;
  final ReaderShortcutBinding? shortcut;
  final Widget child;
  final ShortcutTooltipPlacement placement;
  final double sideGap;

  TooltipPositionDelegate? get _positionDelegate {
    return switch (placement) {
      ShortcutTooltipPlacement.defaultPosition => null,
      ShortcutTooltipPlacement.right => (context) {
        final left = context.target.dx + context.targetSize.width / 2 + sideGap;
        final top = context.target.dy - context.tooltipSize.height / 2;
        return Offset(
          left.clamp(
            0.0,
            context.overlaySize.width - context.tooltipSize.width,
          ),
          top.clamp(
            0.0,
            context.overlaySize.height - context.tooltipSize.height,
          ),
        );
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final binding = shortcut;
    final positionDelegate = _positionDelegate;
    return TooltipTheme(
      data: const TooltipThemeData(
        decoration: BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        padding: EdgeInsets.fromLTRB(14, 8, 8, 8),
        constraints: BoxConstraints(maxWidth: 300),
        textStyle: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
        waitDuration: Duration(milliseconds: 450),
        showDuration: Duration(milliseconds: 2600),
      ),
      child: binding == null
          ? Tooltip(
              message: label,
              positionDelegate: positionDelegate,
              child: child,
            )
          : Tooltip(
              positionDelegate: positionDelegate,
              richMessage: TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 14,
                    ),
                  ),
                  _ShortcutBadgeSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          child: Text(
                            binding.label,
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 13,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              child: child,
            ),
    );
  }
}

class _ShortcutBadgeSpan extends WidgetSpan {
  const _ShortcutBadgeSpan({required super.child, super.alignment});

  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) {}
}
