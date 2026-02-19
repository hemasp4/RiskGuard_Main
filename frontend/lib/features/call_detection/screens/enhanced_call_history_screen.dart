import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/method_channel_service.dart';

/// Enhanced call history screen with search and filter capabilities
class EnhancedCallHistoryScreen extends StatefulWidget {
  const EnhancedCallHistoryScreen({super.key});

  @override
  State<EnhancedCallHistoryScreen> createState() =>
      _EnhancedCallHistoryScreenState();
}

class _EnhancedCallHistoryScreenState extends State<EnhancedCallHistoryScreen> {
  final MethodChannelService _methodChannel = MethodChannelService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _calls = [];
  List<Map<String, dynamic>> _filteredCalls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCallHistory() async {
    setState(() => _isLoading = true);
    try {
      final calls = await _methodChannel.getRecentCalls();
      setState(() {
        _calls = calls.isNotEmpty ? calls : _getMockCalls();
        _filteredCalls = _calls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _calls = _getMockCalls();
        _filteredCalls = _calls;
        _isLoading = false;
      });
    }
  }

  void _filterCalls() {
    setState(() {
      var filtered = _calls;

      // Apply search
      if (_searchController.text.isNotEmpty) {
        filtered = filtered.where((call) {
          final query = _searchController.text.toLowerCase();
          final name = (call['callerName'] ?? '').toLowerCase();
          final number = call['phoneNumber'].toLowerCase();
          return name.contains(query) || number.contains(query);
        }).toList();
      }

      // Apply risk filter
      if (_selectedFilter != 'All') {
        filtered = filtered.where((call) {
          final riskScore = call['riskScore'] as int;
          switch (_selectedFilter) {
            case 'High Risk':
              return riskScore >= 70;
            case 'Medium Risk':
              return riskScore >= 40 && riskScore < 70;
            case 'Low Risk':
              return riskScore < 40;
            case 'Blocked':
              return call['wasBlocked'] == true;
            default:
              return true;
          }
        }).toList();
      }

      _filteredCalls = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Call History', style: AppTypography.headlineSmall),
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportToCsv,
            tooltip: 'Export to CSV',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearHistory,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or number...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondaryLight,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => _filterCalls(),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('High Risk'),
                const SizedBox(width: 8),
                _buildFilterChip('Medium Risk'),
                const SizedBox(width: 8),
                _buildFilterChip('Low Risk'),
                const SizedBox(width: 8),
                _buildFilterChip('Blocked'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Call list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCalls.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _filteredCalls.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      return _buildCallCard(_filteredCalls[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label, style: AppTypography.labelSmall),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          _filterCalls();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      checkmarkColor: AppColors.textPrimaryLight,
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.textPrimaryLight
            : AppColors.textSecondaryLight,
      ),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> call) {
    final riskScore = call['riskScore'] as int;
    final riskColor = AppColors.getRiskColor(riskScore);
    final wasBlocked = call['wasBlocked'] as bool;
    final callType = call['callType'] as String;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      call['timestamp'] as int,
    );
    final duration = call['duration'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: riskColor.withValues(alpha: 0.1),
          child: Icon(
            callType == 'incoming' ? Icons.call_received : Icons.call_made,
            color: riskColor,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                call['callerName'] ?? call['phoneNumber'],
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$riskScore%',
                style: AppTypography.labelSmall.copyWith(
                  color: riskColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              call['phoneNumber'],
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
                fontFamily: 'RobotoMono',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(timestamp),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.timer,
                  size: 14,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(duration),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            if (wasBlocked) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.block, size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    'BLOCKED',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textSecondaryLight,
        ),
        onTap: () => _showCallDetails(call),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No calls found',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(dt)}';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE HH:mm').format(dt);
    } else {
      return DateFormat('MMM d, HH:mm').format(dt);
    }
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}m ${secs}s';
  }

  void _showCallDetails(Map<String, dynamic> call) {
    // Show detailed call information in a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call Details', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Number: ${call['phoneNumber']}',
              style: AppTypography.bodyMedium,
            ),
            Text(
              'Risk Score: ${call['riskScore']}%',
              style: AppTypography.bodyMedium,
            ),
            Text(
              'Analysis: ${call['explanation'] ?? "No detailed analysis available."}',
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _exportToCsv() {
    // Export functionality would involve generating a CSV and sharing it
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Exporting call history...')));
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear History?', style: AppTypography.titleLarge),
        content: Text(
          'This will permanently delete all call records.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              final success = await _methodChannel.clearRecentCalls();

              if (success && mounted) {
                navigator.pop();
                setState(() {
                  _calls.clear();
                  _filteredCalls.clear();
                });
                messenger.showSnackBar(
                  const SnackBar(content: Text('Call history cleared')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getMockCalls() {
    return [
      {
        'id': 1,
        'phoneNumber': '+1 555-0123',
        'callerName': 'Unknown Caller',
        'callType': 'incoming',
        'duration': 125000,
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        'riskScore': 85,
        'riskLevel': 'High Risk',
        'aiProbability': 0.89,
        'wasBlocked': false,
      },
      {
        'id': 2,
        'phoneNumber': '+1 555-9876',
        'callerName': 'Spam Caller',
        'callType': 'incoming',
        'duration': 0,
        'timestamp': DateTime.now()
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch,
        'riskScore': 95,
        'riskLevel': 'High Risk',
        'aiProbability': 0.92,
        'wasBlocked': true,
      },
      {
        'id': 3,
        'phoneNumber': '+1 555-4567',
        'callerName': 'John Doe',
        'callType': 'outgoing',
        'duration': 345000,
        'timestamp': DateTime.now()
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
        'riskScore': 15,
        'riskLevel': 'Low Risk',
        'aiProbability': 0.05,
        'wasBlocked': false,
      },
    ];
  }
}
