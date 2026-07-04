import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../widgets/subject_card.dart';
import '../theme/app_theme.dart';
import 'analytics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dashboard = app.dashboard;

    return Scaffold(
      appBar: AppBar(title: const Text('AttendX')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refreshAll(),
        child: app.isLoading && dashboard == null
            ? const Center(child: CircularProgressIndicator())
            : dashboard == null
                ? Center(
                    child: Text(app.error ?? 'No data yet. Add subjects & a timetable to begin.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _OverallCard(percentage: dashboard.overallPercentage),
                      const SizedBox(height: 20),
                      Text('Subjects', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (dashboard.subjects.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('No subjects yet. Go to Subjects tab to add one.'),
                        ),
                      ...dashboard.subjects.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SubjectCard(
                              data: s,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AnalyticsScreen(subject: s)),
                              ),
                            ),
                          )),
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          'Created by PRAFUL SINGH',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final double percentage;
  const _OverallCard({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 75
        ? StatusColors.safe
        : percentage >= 65
            ? StatusColors.warning
            : StatusColors.critical;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Attendance', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 64,
              width: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (percentage / 100).clamp(0, 1),
                    strokeWidth: 7,
                    color: color,
                    backgroundColor: color.withOpacity(0.15),
                  ),
                  Icon(Icons.check_circle, color: color, size: 22),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
