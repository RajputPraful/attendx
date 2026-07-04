import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'animated_progress_bar.dart';

class SubjectCard extends StatelessWidget {
  final SubjectDashboard data;
  final VoidCallback? onTap;

  const SubjectCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final periodDuration = context.watch<AppState>().periodDurationMinutes;
    final statusColor = StatusColors.forStatus(data.status);

    // Convert hours → periods using user's setting
    final totalPeriods = (data.totalClasses * 60 / periodDuration).round();
    final attendedPeriods = (data.attendedClasses * 60 / periodDuration).round();

    // Safe bunks in periods (negative means periods needed to recover)
    final safeBunkPeriods = (data.safeBunks * 60 / periodDuration).floor();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${data.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (data.code != null) ...[
                const SizedBox(height: 2),
                Text(data.code!, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              AnimatedProgressBar(percentage: data.percentage, color: statusColor),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$attendedPeriods/$totalPeriods Periods attended',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    safeBunkPeriods >= 0
                        ? 'Can miss: $safeBunkPeriods ${safeBunkPeriods == 1 ? "Period" : "Periods"}'
                        : 'Need ${safeBunkPeriods.abs()} more to recover',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
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
}
