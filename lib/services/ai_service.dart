import 'dart:math';
import '../models/task_item.dart';

class AIService {
  // Initial demo tasks
  final List<TaskItem> _tasks = [
    TaskItem(
      id: '1',
      title: 'Finalize Q4 Revenue Projections',
      description: 'Sync with Sarah on EMEA numbers before EOD Friday.',
      priority: TaskPriority.high,
      dueDate: 'Oct 24',
      assignees: ['JD', 'SK'],
      isCompleted: false,
    ),
    TaskItem(
      id: '2',
      title: 'Update Design Tokens for v2.0',
      description: 'Ensure all color roles match Material 3 spec.',
      priority: TaskPriority.medium,
      dueDate: 'Oct 26',
      assignees: ['AA'],
      isCompleted: false,
    ),
  ];

  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  void toggleTaskCompletion(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index != -1) {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
    }
  }

  // Generates new tasks based on input transcript and appends them
  List<TaskItem> generateTasksFromTranscript(String transcript) {
    if (transcript.trim().isEmpty) return _tasks;

    // Simple heuristic parser for dynamic feeling
    final normalized = transcript.toLowerCase();
    final newTasks = <TaskItem>[];

    if (normalized.contains('bug') || normalized.contains('fix') || normalized.contains('issue')) {
      newTasks.add(
        TaskItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_1',
          title: 'Resolve critical layout overflow bug',
          description: 'Fix bento grid container height issues on mobile resolutions.',
          priority: TaskPriority.high,
          dueDate: _getFutureDateShort(2),
          assignees: ['JD'],
        ),
      );
    }

    if (normalized.contains('test') || normalized.contains('verify') || normalized.contains('check')) {
      newTasks.add(
        TaskItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_2',
          title: 'Perform cross-device UI verification',
          description: 'Test backdrop filter performance on lower-end devices.',
          priority: TaskPriority.medium,
          dueDate: _getFutureDateShort(4),
          assignees: ['AA', 'SK'],
        ),
      );
    }

    if (normalized.contains('deploy') || normalized.contains('release') || normalized.contains('push')) {
      newTasks.add(
        TaskItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_3',
          title: 'Prepare staging environment deployment',
          description: 'Merge feature branches and verify action-gen workflow nodes.',
          priority: TaskPriority.high,
          dueDate: _getFutureDateShort(1),
          assignees: ['JD', 'AA'],
        ),
      );
    }

    // Default general task if none of the keywords match
    if (newTasks.isEmpty) {
      // Split transcript into lines or limit length for the title
      String title = transcript.split('\n').first;
      if (title.length > 40) {
        title = '${title.substring(0, 37)}...';
      }
      newTasks.add(
        TaskItem(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          description: transcript.length > 40 ? transcript : 'Extracted from user meeting notes/transcript brief.',
          priority: Random().nextBool() ? TaskPriority.medium : TaskPriority.low,
          dueDate: _getFutureDateShort(3),
          assignees: ['SK'],
        ),
      );
    }

    // Prepend the new tasks so they show up at the top
    _tasks.insertAll(0, newTasks);
    return _tasks;
  }

  String _getFutureDateShort(int daysAhead) {
    final date = DateTime.now().add(Duration(days: daysAhead));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
