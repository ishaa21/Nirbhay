import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/gradient_button.dart';
import '../widgets/status_pill.dart';
import '../widgets/task_card.dart';
import '../widgets/top_app_bar.dart';
import '../widgets/workflow_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _transcriptController = TextEditingController();
  late List<TaskItem> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = List.from(_aiService.tasks);
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  void _handleToggleTask(String id) {
    setState(() {
      _aiService.toggleTaskCompletion(id);
      _tasks = List.from(_aiService.tasks);
    });
  }

  void _handleGenerateActions() {
    final text = _transcriptController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceContainerHigh,
          content: const Text(
            'Please paste some meeting transcript first!',
            style: TextStyle(color: AppColors.onSurface),
          ),
        ),
      );
      return;
    }

    setState(() {
      _tasks = List.from(_aiService.generateTasksFromTranscript(text));
      _transcriptController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryDim,
        content: const Text(
          'AI sync complete. Action items extracted!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  int get _pendingCount => _tasks.where((task) => !task.isCompleted).length;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const TopAppBar(),
      bottomNavigationBar: isDesktop ? null : const BottomNavBar(),
      body: Stack(
        children: [
          // 1. Base dark background
          Container(
            color: AppColors.background,
          ),
          // 2. Left top indigo glow
          Positioned(
            left: -150,
            top: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 3. Right top violet glow
          Positioned(
            right: -150,
            top: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFAC8AFF).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 4. Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32.0 : 16.0,
                vertical: 24.0,
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      _buildHeaderSection(),
                      const SizedBox(height: 24),
                      // Input Workspace Card
                      _buildInputCard(),
                      // Large editorial spacing
                      const SizedBox(height: 48),
                      // Main Grid / Layout
                      isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
                      // Generous bottom spacing for floating UI breathing room
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meeting Workspace',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.02,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Transform meeting notes into action items instantly.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const StatusPill(),
      ],
    );
  }

  Widget _buildInputCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(1.0),
      borderRadius: 16,
      opacity: 0.5,
      child: GlassContainer(
        borderRadius: 15,
        padding: const EdgeInsets.all(18),
        opacity: 0.3,
        fillColor: AppColors.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRANSCRIPT OR BRIEF',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                TextField(
                  controller: _transcriptController,
                  maxLines: 4,
                  minLines: 4,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste your meeting notes here...',
                    contentPadding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 48, // space for buttons
                    ),
                  ),
                ),
                // Attachment & Audio Mic actions
                Padding(
                  padding: const EdgeInsets.only(right: 12.0, bottom: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.attach_file,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.mic,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GradientButton(
                  onPressed: _handleGenerateActions,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.flash_on,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Generate Actions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tasks section (7/12 width)
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTasksHeader(),
              const SizedBox(height: 16),
              ..._tasks.map(
                (task) => TaskCard(
                  key: ValueKey(task.id),
                  task: task,
                  onCompletionChanged: (_) => _handleToggleTask(task.id),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Workflow section (5/12 width)
        Expanded(
          flex: 5,
          child: Container(
            constraints: const BoxConstraints(minHeight: 380), // Responsive min-height instead of fixed height
            child: const WorkflowPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTasksHeader(),
        const SizedBox(height: 16),
        ..._tasks.map(
          (task) => TaskCard(
            key: ValueKey(task.id),
            task: task,
            onCompletionChanged: (_) => _handleToggleTask(task.id),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          constraints: const BoxConstraints(minHeight: 340), // Responsive min-height instead of fixed height
          child: const WorkflowPanel(),
        ),
      ],
    );
  }

  Widget _buildTasksHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'Extracted Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.02,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            '$_pendingCount PENDING',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
