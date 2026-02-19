import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/method_channel_service.dart';

/// Whitelist management screen - manage trusted contacts
class WhitelistScreen extends StatefulWidget {
  const WhitelistScreen({super.key});

  @override
  State<WhitelistScreen> createState() => _WhitelistScreenState();
}

class _WhitelistScreenState extends State<WhitelistScreen> {
  final MethodChannelService _methodChannel = MethodChannelService();
  List<Map<String, dynamic>> _whitelistedContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWhitelistedContacts();
  }

  Future<void> _loadWhitelistedContacts() async {
    setState(() => _isLoading = true);
    final contacts = await _methodChannel.getSavedContacts();
    setState(() {
      _whitelistedContacts = contacts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Trusted Contacts', style: AppTypography.headlineSmall),
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Whitelisted contacts skip risk analysis for faster, safer calls.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Whitelisted contacts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _whitelistedContacts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _whitelistedContacts.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      return _buildContactCard(_whitelistedContacts[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addToWhitelist,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimaryLight,
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
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
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          child: Icon(Icons.verified_user, color: AppColors.success),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                contact['name'],
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'VIP',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              contact['phoneNumber'],
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
                fontFamily: 'RobotoMono',
              ),
            ),
            if (contact['email'] != null && contact['email'].isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                contact['email'],
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
            if (contact['company'] != null &&
                contact['company'].isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.business,
                    size: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    contact['company'],
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.remove_circle_outline, color: AppColors.error),
          onPressed: () => _removeFromWhitelist(contact),
          tooltip: 'Remove from whitelist',
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user,
            size: 64,
            color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Trusted Contacts',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Add trusted contacts to skip risk analysis and speed up calls',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToWhitelist() {
    // Contact picker or input dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Contact whitelist feature'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _removeFromWhitelist(Map<String, dynamic> contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove from Whitelist?', style: AppTypography.titleLarge),
        content: Text(
          'Risk analysis will resume for calls from ${contact['name']}.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Remove from native database
              Navigator.pop(context);
              setState(() {
                _whitelistedContacts.remove(contact);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${contact['name']} removed from whitelist'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
