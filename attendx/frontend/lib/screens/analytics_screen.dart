import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_providers.dart';
import '../models/dashboard.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  final SubjectDashboard subject;
  const AnalyticsScreen({super.key, required this.subject});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  int _missedInput = 0;
  Map<String, dynamic>? _prediction;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final engine = context.read<AppState>().engine;
    final data = await engine.getTrend(widget.subject.subjectId);
    setState(() => _analytics = data);
  }

  Future<void> _runPrediction(int missed) async {
    final engine = context.read<AppState>().engine;
    final result = await engine.predict(widget.subject.subjectId, missed: missed);
    setState(() {
      _missedInput = missed;
      _prediction = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subject;
    final periodDuration = context.watch<AppState>().periodDurationMinutes;
    final statusColor = StatusColors.forStatus(s.status);
    final trend = (_analytics?['trend'] as List?) ?? [];

    // Convert hours → periods
    final totalPeriods = (s.totalClasses * 60 / periodDuration).round();
    final attendedPeriods = (s.attendedClasses * 60 / periodDuration).round();
    final safeBunkPeriods = (s.safeBunks * 60 / periodDuration).floor();

    // classes_needed_to_recover is already counted in class "units" (hours).
    // Convert to periods for display.
    final rawRecover = _analytics?['classes_needed_to_recover'];
    final recoverPeriods = rawRecover != null
        ? ((rawRecover as num).toDouble() * 60 / periodDuration).ceil()
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current standing', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${s.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                  Text(
                    'Required: ${s.requiredPercentage.toStringAsFixed(0)}%  •  '
                    '$attendedPeriods/$totalPeriods Periods attended',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    safeBunkPeriods >= 0
                        ? '✓ You can safely miss $safeBunkPeriods more ${safeBunkPeriods == 1 ? "Period" : "Periods"}'
                        : '⚠ Attend ${safeBunkPeriods.abs()} more ${safeBunkPeriods.abs() == 1 ? "Period" : "Periods"} to recover',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (s.status != 'SAFE' && recoverPeriods != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: statusColor, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Attend $recoverPeriods consecutive ${recoverPeriods == 1 ? "Period" : "Periods"} to recover.',
                              style: TextStyle(color: statusColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Attendance Trend', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: trend.isEmpty
                ? const Center(child: Text('Not enough data yet'))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: const FlTitlesData(
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < trend.length; i++)
                              FlSpot(i.toDouble(), (trend[i]['cumulative_percentage'] as num).toDouble()),
                          ],
                          isCurved: true,
                          color: statusColor,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: statusColor.withOpacity(0.15)),
                        ),
                        LineChartBarData(
                          spots: [
                            FlSpot(0, s.requiredPercentage),
                            FlSpot((trend.length - 1).toDouble().clamp(0, double.infinity), s.requiredPercentage),
                          ],
                          isCurved: false,
                          color: Colors.grey,
                          dashArray: [6, 4],
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text('Prediction: "What if I miss the next few Periods?"',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              final n = i + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Miss $n'),
                  selected: _missedInput == n,
                  onSelected: (_) => _runPrediction(n),
                ),
              );
            }),
          ),
          if (_prediction != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _prediction!['will_be_below_required'] == true
                  ? StatusColors.critical.withOpacity(0.1)
                  : StatusColors.safe.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'If you miss $_missedInput more ${_missedInput == 1 ? "Period" : "Periods"}, '
                  'attendance projects to '
                  '${(_prediction!['projected_percentage'] as num).toStringAsFixed(1)}% '
                  '(currently ${(_prediction!['current_percentage'] as num).toStringAsFixed(1)}%).',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
