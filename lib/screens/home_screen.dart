import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  TaskStatus? _filterStatus;
  TaskPriority? _filterPriority;
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Provider.of<TaskProvider>(context, listen: false).loadTasks(); // Load tasks on startup
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.network_check),
            onPressed: () async {
              final result = await Provider.of<TaskProvider>(context, listen: false).testConnection();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result ? 'Connected to server' : 'Failed to connect to server'),
                  backgroundColor: result ? Colors.green : Colors.red,
                ),
              );
            },
            tooltip: 'Test Connection',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => taskProvider.syncTasks(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'filter':
                  _showFilterDialog(context);
                  break;
                case 'search':
                  _showSearchBar(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(Icons.filter_list),
                    SizedBox(width: 8),
                    Text('Filter'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 8),
                    Text('Search'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList(taskProvider.filterTasks(
            status: _filterStatus,
            priority: _filterPriority,
          )),
          _buildTaskList(taskProvider.inProgressTasks),
          _buildTaskList(taskProvider.completedTasks),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No tasks found'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          onTap: () => _showEditTaskDialog(context, task),
          onDelete: () => _showDeleteConfirmation(context, task),
          onStatusChange: (status) {
            Provider.of<TaskProvider>(context, listen: false)
                .updateTaskStatus(task, status);
          },
          onPriorityChange: (priority) {
            Provider.of<TaskProvider>(context, listen: false)
                .updateTaskPriority(task, priority);
          },
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Tasks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<TaskStatus?>(
              value: _filterStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All'),
                ),
                ...TaskStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _filterStatus = value;
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskPriority?>(
              value: _filterPriority,
              decoration: const InputDecoration(
                labelText: 'Priority',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All'),
                ),
                ...TaskPriority.values.map((priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority.label),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _filterPriority = value;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterStatus = null;
                _filterPriority = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear Filters'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSearchBar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TaskForm(
          onSubmit: (task) {
            Provider.of<TaskProvider>(context, listen: false).addTask(task);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TaskForm(
          task: task,
          onSubmit: (updatedTask) {
            Provider.of<TaskProvider>(context, listen: false)
                .updateTask(updatedTask);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<TaskProvider>(context, listen: false)
                  .deleteTask(task.id!);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
