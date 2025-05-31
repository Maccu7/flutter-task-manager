import 'package:flutter/material.dart';
import '../models/task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Function(TaskStatus)? onStatusChange;
  final Function(TaskPriority)? onPriorityChange;

  const TaskCard({
    Key? key,
    required this.task,
    this.onTap,
    this.onDelete,
    this.onStatusChange,
    this.onPriorityChange,
  }) : super(key: key);

  bool get isOverdue {
    return task.status != TaskStatus.completed &&
        task.dueDate.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue ? Colors.red.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration: task.status == TaskStatus.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.status == TaskStatus.completed
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isOverdue ? Colors.red : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d, y • h:mm a').format(task.dueDate),
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: isOverdue ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                task.description,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPriorityChip(),
                  _buildStatusChip(),
                  if (task.updatedAt != null)
                    Flexible(
                      child: Text(
                        'Updated ${DateFormat.yMMMd().format(task.updatedAt!)}',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;
    switch (task.status) {
      case TaskStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case TaskStatus.inProgress:
        icon = Icons.pending;
        color = Colors.blue;
        break;
      case TaskStatus.pending:
        icon = Icons.radio_button_unchecked;
        color = Colors.grey;
        break;
    }

    return InkWell(
      onTap: onStatusChange != null
          ? () => _showStatusChangeDialog(icon, color)
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildPriorityChip() {
    return InkWell(
      onTap: onPriorityChange != null
          ? () => _showPriorityChangeDialog()
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              task.priority.label,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: task.priority.color,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildStatusChip() {
    return Chip(
      label: Text(
        task.status.label,
        style: GoogleFonts.roboto(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: task.status.color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _showStatusChangeDialog(IconData currentIcon, Color currentColor) async {
    if (onStatusChange == null) return;

    final BuildContext context = _getContext();
    if (context == null) return;

    final TaskStatus? newStatus = await showDialog<TaskStatus>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Status', style: GoogleFonts.roboto()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: TaskStatus.values.map((status) {
              IconData icon;
              switch (status) {
                case TaskStatus.completed:
                  icon = Icons.check_circle;
                  break;
                case TaskStatus.inProgress:
                  icon = Icons.pending;
                  break;
                case TaskStatus.pending:
                  icon = Icons.radio_button_unchecked;
                  break;
              }

              return ListTile(
                leading: Icon(icon, color: status.color),
                title: Text(status.label, style: GoogleFonts.roboto()),
                selected: status == task.status,
                onTap: () => Navigator.of(context).pop(status),
              );
            }).toList(),
          ),
        );
      },
    );

    if (newStatus != null && newStatus != task.status) {
      onStatusChange!(newStatus);
    }
  }

  Future<void> _showPriorityChangeDialog() async {
    if (onPriorityChange == null) return;

    final BuildContext context = _getContext();
    if (context == null) return;

    final TaskPriority? newPriority = await showDialog<TaskPriority>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Priority', style: GoogleFonts.roboto()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: TaskPriority.values.map((priority) {
              return ListTile(
                leading: Icon(Icons.flag, color: priority.color),
                title: Text(priority.label, style: GoogleFonts.roboto()),
                selected: priority == task.priority,
                onTap: () => Navigator.of(context).pop(priority),
              );
            }).toList(),
          ),
        );
      },
    );

    if (newPriority != null && newPriority != task.priority) {
      onPriorityChange!(newPriority);
    }
  }

  BuildContext _getContext() {
    try {
      return _key.currentContext!;
    } catch (e) {
      return throw Exception('Context not available');
    }
  }

  static final GlobalKey _key = GlobalKey();
}
