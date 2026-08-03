import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool enableHoverEffect;
  final double? width;
  final double? height;
  final Color? fillColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 24.0,
    this.opacity = 0.4,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.enableHoverEffect = false,
    this.width,
    this.height,
    this.fillColor,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Under hover, shift background to slightly brighter color and scale up
    final scale = _isHovered ? 1.02 : 1.00;
    final activeFillColor = widget.fillColor ??
        (_isHovered ? AppColors.surfaceBright : AppColors.surfaceContainerHighest);

    Widget container = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      transform: Matrix4.diagonal3Values(scale, scale, 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: activeFillColor.withOpacity(widget.opacity),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.15),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(_isHovered ? 0.4 : 0.3),
            blurRadius: 50.0,
            spreadRadius: -5.0,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: Stack(
            children: [
              // Subtle Gradient Overlay to provide "soul" (Primary-dim to Secondary at 15% opacity)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryDim.withOpacity(0.08),
                        AppColors.secondary.withOpacity(0.08),
                      ],
                    ),
                  ),
                ),
              ),
              // Content Padding
              Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.enableHoverEffect) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: container,
      );
    }

    return container;
  }
}
