import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../theme/app_colors.dart';
import 'glass_container.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final ValueChanged<bool?> onCompletionChanged;

  const TaskCard({
    super.key,
    required this.task,
    required this.onCompletionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassContainer(
        enableHoverEffect: true,
        padding: const EdgeInsets.all(16.0),
        fillColor: AppColors.surfaceContainerLow,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Transform.translate(
              offset: const Offset(-4, 0),
              child: Checkbox(
                value: task.isCompleted,
                onChanged: onCompletionChanged,
                activeColor: AppColors.primaryDim,
              ),
            ),
            const SizedBox(width: 4),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Priority Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurface,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityBadge(task.priority),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Description
                  Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Date and Assignees Stack
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Due Date
                      Row(
                        mainAxisSize: MainAxisSize.min, // Limit Row width inside Wrap
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 13,
                            color: AppColors.onSurfaceVariant.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.dueDate.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      // Assignees overlap stack
                      _buildAssigneesStack(task.assignees),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color badgeColor;
    Color textColor;
    IconData icon;
    String label;

    switch (priority) {
      case TaskPriority.high:
        badgeColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.error;
        icon = Icons.priority_high;
        label = 'High';
        break;
      case TaskPriority.medium:
        badgeColor = AppColors.secondary.withOpacity(0.1);
        textColor = AppColors.secondary;
        icon = Icons.adjust;
        label = 'Medium';
        break;
      case TaskPriority.low:
        badgeColor = AppColors.primary.withOpacity(0.1);
        textColor = AppColors.primary;
        icon = Icons.info_outline;
        label = 'Low';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneesStack(List<String> assignees) {
    if (assignees.isEmpty) return const SizedBox.shrink();

    // Limit showable avatars to 3
    final listToShow = assignees.take(3).toList();
    final remainingCount = assignees.length - listToShow.length;

    List<Widget> children = [];
    for (int i = 0; i < listToShow.length; i++) {
      // Overlapping offset
      final double offset = i * 12.0;

      // Color scheme based on index to differentiate
      final Color bg = i == 0
          ? Color(0xFF6366F1)
          : i == 1
              ? Color(0xFF8B5CF6)
              : Color(0xFF06B6D4);

      children.add(
        Positioned(
          left: offset,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surfaceContainerLow,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              listToShow[i],
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    if (remainingCount > 0) {
      final double offset = listToShow.length * 12.0;
      children.add(
        Positioned(
          left: offset,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surfaceContainerLow,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '+$remainingCount',
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    // Calculated total width of stack
    final double stackWidth = (listToShow.length * 12.0) + (remainingCount > 0 ? 20.0 : 8.0);

    return SizedBox(
      height: 20,
      width: stackWidth + 10.0,
      child: Stack(
        children: children,
      ),
    );
  }
}
