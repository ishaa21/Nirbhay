enum TaskPriority {
  high,
  medium,
  low,
}

class TaskItem {
  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final String dueDate;
  final List<String> assignees;
  bool isCompleted;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.assignees,
    this.isCompleted = false,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    TaskPriority? priority,
    String? dueDate,
    List<String>? assignees,
    bool? isCompleted,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      assignees: assignees ?? this.assignees,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
