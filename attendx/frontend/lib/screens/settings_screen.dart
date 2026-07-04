import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DateTime start = DateTime.now();
  DateTime end = DateTime.now().add(const Duration(days: 120));
  bool saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = context.read<AppState>().db;
      final sem = await db.getSemester();
      if (sem != null && mounted) {
        setState(() {
          start = DateTime.parse(sem['start_date']);
          end = DateTime.parse(sem['end_date']);
        });
      }
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? start : end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => isStart ? start = picked : end = picked);
  }

  Future<void> _saveSemester() async {
    setState(() => saving = true);
    final db = context.read<AppState>().db;
    await db.setSemester({
      'name': 'Current Semester',
      'start_date': start.toIso8601String().split('T').first,
      'end_date': end.toIso8601String().split('T').first,
      'saturday_enabled': 0,
    });
    setState(() => saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semester saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Attendance Period ──────────────────────────────────
          Text('Attendance Period', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Set how many minutes one period is at your institution. '
            'All attendance counts will be shown in periods.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Base Period Duration',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  DropdownButton<int>(
                    value: app.periodDurationMinutes,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 40, child: Text('40 min')),
                      DropdownMenuItem(value: 45, child: Text('45 min')),
                      DropdownMenuItem(value: 50, child: Text('50 min')),
                      DropdownMenuItem(value: 55, child: Text('55 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                      DropdownMenuItem(value: 75, child: Text('75 min')),
                      DropdownMenuItem(value: 90, child: Text('90 min')),
                    ],
                    onChanged: (v) {
                      if (v != null) app.setPeriodDuration(v);
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'Currently: 1 Period = ${app.periodDurationMinutes} minutes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),

          const SizedBox(height: 24),
          // ── Semester ──────────────────────────────────────────
          Text('Semester Setup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Start date'),
                  subtitle: Text(start.toIso8601String().split('T').first),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(true),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('End date'),
                  subtitle: Text(end.toIso8601String().split('T').first),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: saving ? null : _saveSemester,
            child: Text(saving ? 'Saving...' : 'Save Semester'),
          ),

          const SizedBox(height: 28),
          // ── Appearance ────────────────────────────────────────
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Dark mode'),
                  value: ThemeMode.dark,
                  groupValue: app.themeMode,
                  onChanged: (v) => app.setThemeMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Light mode'),
                  value: ThemeMode.light,
                  groupValue: app.themeMode,
                  onChanged: (v) => app.setThemeMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Follow system'),
                  value: ThemeMode.system,
                  groupValue: app.themeMode,
                  onChanged: (v) => app.setThemeMode(v!),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          // ── Notifications ─────────────────────────────────────
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: const [
                SwitchListTile(title: Text('Morning schedule reminder'), value: true, onChanged: null),
                SwitchListTile(title: Text('Low attendance warnings'), value: true, onChanged: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
