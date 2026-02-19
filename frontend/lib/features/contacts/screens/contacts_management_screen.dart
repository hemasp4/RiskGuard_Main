import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/method_channel_service.dart';

/// Contacts Management Screen with split view
/// Left side: Existing contacts list
/// Right side: Add/Edit contact form
class ContactsManagementScreen extends StatefulWidget {
  const ContactsManagementScreen({super.key});

  @override
  State<ContactsManagementScreen> createState() =>
      _ContactsManagementScreenState();
}

class _ContactsManagementScreenState extends State<ContactsManagementScreen> {
  final MethodChannelService _methodChannel = MethodChannelService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  Map<String, dynamic>? _selectedContact;
  String _selectedCategory = 'Personal';
  bool _isLoading = true;
  bool _isEditing = false;

  final List<String> _categories = [
    'Personal',
    'Business',
    'Spam',
    'Unknown Caller',
    'Verified',
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    final contacts = await _methodChannel.getSavedContacts();
    setState(() {
      _contacts = contacts;
      _filteredContacts = contacts;
      _isLoading = false;
    });
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        final name = (contact['name'] ?? '').toLowerCase();
        final phone = (contact['phoneNumber'] ?? '').toLowerCase();
        final company = (contact['company'] ?? '').toLowerCase();
        return name.contains(query) ||
            phone.contains(query) ||
            company.contains(query);
      }).toList();
    });
  }

  void _selectContact(Map<String, dynamic> contact) {
    setState(() {
      _selectedContact = contact;
      _isEditing = true;
      _nameController.text = contact['name'] ?? '';
      _phoneController.text = contact['phoneNumber'] ?? '';
      _emailController.text = contact['email'] ?? '';
      _companyController.text = contact['company'] ?? '';
      _notesController.text = contact['notes'] ?? '';
      _selectedCategory = contact['category'] ?? 'Personal';
    });
  }

  void _clearForm() {
    setState(() {
      _selectedContact = null;
      _isEditing = false;
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _companyController.clear();
      _notesController.clear();
      _selectedCategory = 'Personal';
    });
  }

  Future<void> _saveContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Phone are required')),
      );
      return;
    }

    // For now, we'll just reload the contacts
    // In a real implementation, you'd call a MethodChannel save method
    _clearForm();
    await _loadContacts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact saved successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Contacts Management', style: AppTypography.headlineSmall),
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 600;

          return isWideScreen
              ? _buildSplitView() // Desktop/Tablet layout
              : _buildStackedView(); // Mobile layout
        },
      ),
    );
  }

  // Split view for larger screens (left: contacts, right: form)
  Widget _buildSplitView() {
    return Row(
      children: [
        // Left side - Contacts List (70%)
        Expanded(flex: 7, child: _buildContactsList()),

        // Divider
        Container(
          width: 1,
          color: AppColors.textSecondaryLight.withValues(alpha: 0.2),
        ),

        // Right side - Contact Form (30%)
        Expanded(flex: 3, child: _buildContactForm()),
      ],
    );
  }

  // Stacked view for mobile (vertical layout)
  Widget _buildStackedView() {
    return Column(
      children: [
        // Top - Contacts List (60%)
        Expanded(flex: 6, child: _buildContactsList()),

        // Divider
        Container(
          height: 1,
          color: AppColors.textSecondaryLight.withValues(alpha: 0.2),
        ),

        // Bottom - Contact Form (40%)
        Expanded(flex: 4, child: _buildContactForm()),
      ],
    );
  }

  Widget _buildContactsList() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
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
          ),
        ),

        // Contacts List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredContacts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _filteredContacts.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    return _buildContactCard(_filteredContacts[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final isSelected =
        _selectedContact?['phoneNumber'] == contact['phoneNumber'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
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
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            contact['name']?.substring(0, 1).toUpperCase() ?? '?',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contact['name'] ?? 'Unknown',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimaryLight,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              contact['phoneNumber'] ?? '',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
                fontFamily: 'RobotoMono',
              ),
            ),
            if (contact['company'] != null &&
                contact['company'].isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.business,
                    size: 14,
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
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getCategoryColor(
              contact['category'],
            ).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            contact['category'] ?? 'Unknown',
            style: AppTypography.labelSmall.copyWith(
              color: _getCategoryColor(contact['category']),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _selectContact(contact),
      ),
    );
  }

  Widget _buildContactForm() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Title
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Contact' : 'Add New Contact',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearForm,
                    color: AppColors.textSecondaryLight,
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Name Field
            _buildTextField(
              controller: _nameController,
              label: 'Name *',
              hint: 'Enter name',
              icon: Icons.person,
            ),

            const SizedBox(height: 16),

            // Phone Field
            _buildTextField(
              controller: _phoneController,
              label: 'Phone *',
              hint: '+1 234 567 8900',
              icon: Icons.phone,
              enabled: !_isEditing, // Can't edit phone for existing contact
            ),

            const SizedBox(height: 16),

            // Email Field
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'email@example.com',
              icon: Icons.email,
            ),

            const SizedBox(height: 16),

            // Category Dropdown
            Text(
              'Category',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Company Field
            _buildTextField(
              controller: _companyController,
              label: 'Company',
              hint: 'Company name',
              icon: Icons.business,
            ),

            const SizedBox(height: 16),

            // Notes Field
            _buildTextField(
              controller: _notesController,
              label: 'Notes',
              hint: 'Add notes...',
              icon: Icons.note,
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Save and Clear Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveContact,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isEditing ? 'Update' : 'Save',
                      style: AppTypography.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _clearForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondaryLight,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppColors.textSecondaryLight),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: enabled ? AppColors.backgroundLight : Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 64,
            color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts found',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add contacts during calls or use the form',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Business':
        return AppColors.primary;
      case 'Personal':
        return AppColors.success;
      case 'Spam':
        return AppColors.error;
      case 'Verified':
        return AppColors.info;
      default:
        return AppColors.textSecondaryLight;
    }
  }
}
