import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_container.dart';

class WorkflowPanel extends StatelessWidget {
  const WorkflowPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      fillColor: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.all(20.0),
      child: Stack(
        children: [
          // Background Glow effect in top right
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export Workflow',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Vertical connecting line
                          Positioned(
                            top: 30,
                            bottom: 60,
                            width: 1.5,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),

                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Node 1: AI Engine
                              _buildEngineNode(),
                              
                              // Node 2: Integration Matrix
                              _buildIntegrationMatrix(),

                              // Node 3: Project Launch Card
                              _buildLaunchCard(),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineNode() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      opacity: 0.6,
      fillColor: AppColors.surfaceContainerHigh,
      borderRadius: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDim, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'AI ENGINE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationMatrix() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIconWrapper(
          child: Image.asset(
            'assets/images/jira_logo.png',
            width: 18,
            height: 18,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.blur_circular, size: 18),
          ),
          hoverColor: AppColors.primary,
        ),
        const SizedBox(width: 16),
        _buildIconWrapper(
          child: Image.asset(
            'assets/images/slack_logo.png',
            width: 18,
            height: 18,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.message, size: 18),
          ),
          hoverColor: AppColors.secondary,
        ),
        const SizedBox(width: 16),
        _buildIconWrapper(
          child: CustomPaint(
            size: const Size(18, 18),
            painter: GithubIconPainter(),
          ),
          hoverColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildIconWrapper({required Widget child, required Color hoverColor}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildLaunchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'ACTIVE',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Slack • Jira • GitHub',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          // Manage button
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                'MANAGE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Draw Github silhouette logo path
class GithubIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Scale SVG path down to fit inside the given size
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    path.moveTo(12 * scaleX, 0.297 * scaleY);
    path.cubicTo(
        5.37 * scaleX, 0.297 * scaleY, 
        0 * scaleX, 5.67 * scaleY, 
        0 * scaleX, 12.297 * scaleY);
    path.cubicTo(
        0 * scaleX, 17.6 * scaleY, 
        3.438 * scaleX, 22.097 * scaleY, 
        8.205 * scaleX, 23.682 * scaleY);
    path.cubicTo(
        8.805 * scaleX, 23.795 * scaleY, 
        9.025 * scaleX, 23.424 * scaleY, 
        9.025 * scaleX, 23.105 * scaleY);
    path.cubicTo(
        9.025 * scaleX, 22.82 * scaleY, 
        9.015 * scaleX, 22.065 * scaleY, 
        9.01 * scaleX, 21.065 * scaleY);
    path.cubicTo(
        5.672 * scaleX, 21.789 * scaleY, 
        4.968 * scaleX, 19.454 * scaleY, 
        4.968 * scaleX, 19.454 * scaleY);
    path.cubicTo(
        4.422 * scaleX, 18.07 * scaleY, 
        3.633 * scaleX, 17.7 * scaleY, 
        3.633 * scaleX, 17.7 * scaleY);
    path.cubicTo(
        2.546 * scaleX, 16.956 * scaleY, 
        3.717 * scaleX, 16.971 * scaleY, 
        3.717 * scaleX, 16.971 * scaleY);
    path.cubicTo(
        4.922 * scaleX, 17.055 * scaleY, 
        5.555 * scaleX, 18.207 * scaleY, 
        5.555 * scaleX, 18.207 * scaleY);
    path.cubicTo(
        6.625 * scaleX, 20.042 * scaleY, 
        8.364 * scaleX, 19.512 * scaleY, 
        9.05 * scaleX, 19.204 * scaleY);
    path.cubicTo(
        9.158 * scaleX, 18.428 * scaleY, 
        9.467 * scaleX, 17.899 * scaleY, 
        9.81 * scaleX, 17.599 * scaleY);
    path.cubicTo(
        7.145 * scaleX, 17.299 * scaleY, 
        4.344 * scaleX, 16.267 * scaleY, 
        4.344 * scaleX, 11.669 * scaleY);
    path.cubicTo(
        4.344 * scaleX, 10.359 * scaleY, 
        4.809 * scaleX, 9.289 * scaleY, 
        5.579 * scaleX, 8.449 * scaleY);
    path.cubicTo(
        5.444 * scaleX, 8.146 * scaleY, 
        5.039 * scaleX, 6.926 * scaleY, 
        5.684 * scaleX, 5.273 * scaleY);
    path.cubicTo(
        5.684 * scaleX, 5.273 * scaleY, 
        6.689 * scaleX, 4.951 * scaleY, 
        8.984 * scaleX, 6.504 * scaleY);
    path.cubicTo(
        9.944 * scaleX, 6.237 * scaleY, 
        10.964 * scaleX, 6.105 * scaleY, 
        11.984 * scaleX, 6.099 * scaleY);
    path.cubicTo(
        13.004 * scaleX, 6.105 * scaleY, 
        14.024 * scaleX, 6.237 * scaleY, 
        14.984 * scaleX, 6.504 * scaleY);
    path.cubicTo(
        17.279 * scaleX, 4.951 * scaleY, 
        18.284 * scaleX, 5.273 * scaleY, 
        18.284 * scaleX, 5.273 * scaleY);
    path.cubicTo(
        18.929 * scaleX, 6.926 * scaleY, 
        18.524 * scaleX, 8.146 * scaleY, 
        18.389 * scaleX, 8.449 * scaleY);
    path.cubicTo(
        19.159 * scaleX, 9.289 * scaleY, 
        19.624 * scaleX, 10.359 * scaleY, 
        19.624 * scaleX, 11.669 * scaleY);
    path.cubicTo(
        19.624 * scaleX, 16.277 * scaleY, 
        16.82 * scaleX, 17.294 * scaleY, 
        14.15 * scaleX, 17.589 * scaleY);
    path.cubicTo(
        14.58 * scaleX, 17.961 * scaleY, 
        14.973 * scaleX, 18.691 * scaleY, 
        14.973 * scaleX, 19.811 * scaleY);
    path.cubicTo(
        14.973 * scaleX, 21.417 * scaleY, 
        14.958 * scaleX, 22.707 * scaleY, 
        14.958 * scaleX, 23.097 * scaleY);
    path.cubicTo(
        14.958 * scaleX, 23.412 * scaleY, 
        15.168 * scaleX, 23.787 * scaleY, 
        15.783 * scaleX, 23.667 * scaleY);
    path.cubicTo(
        20.565 * scaleX, 22.092 * scaleY, 
        24 * scaleX, 17.592 * scaleY, 
        24 * scaleX, 12.297 * scaleY);
    path.cubicTo(
        24 * scaleX, 5.67 * scaleY, 
        18.627 * scaleX, 0.297 * scaleY, 
        12 * scaleX, 0.297 * scaleY);
    
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
