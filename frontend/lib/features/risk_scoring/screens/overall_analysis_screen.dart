import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/overall_analysis_provider.dart';
import '../widgets/analysis_dashboard_view.dart';

class OverallAnalysisScreen extends StatelessWidget {
  const OverallAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Overall Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<OverallAnalysisProvider>().refresh();
            },
          ),
        ],
      ),
      body: const AnalysisDashboardView(),
    );
  }
}
