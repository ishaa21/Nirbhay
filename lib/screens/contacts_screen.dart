import 'package:flutter/material.dart';
import '../models/emergency_contact_model.dart';
import '../services/contact_service.dart';
import '../l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────
//  Emergency Contacts Screen (Connected to Backend)
// ─────────────────────────────────────────────────────────────────
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // ── Color tokens (match design system) ─────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _outlineVariant = Color(0xFFD1C3C9);

  final EmergencyContactService _contactService = EmergencyContactService();

  bool _isLoading = true;
  String? _errorMessage;
  List<EmergencyContactModel> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _contactService.fetchContacts();

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _contacts = res['contacts'] as List<EmergencyContactModel>;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = AppLocalizations.of(context).localizeBackendMessage(res['message'] as String?, fallback: AppLocalizations.of(context).unableToLoadContacts);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAutoAlert(EmergencyContactModel contact, bool newValue) async {
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index == -1) return;

    // Optimistic UI update
    final oldAutoAlert = contact.autoAlert;
    setState(() {
      _contacts[index] = contact.copyWith(autoAlert: newValue);
    });

    final res = await _contactService.updateContact(contact.id, autoAlert: newValue);

    if (!mounted) return;

    if (res['success'] != true) {
      // Revert on failure
      setState(() {
        _contacts[index] = contact.copyWith(autoAlert: oldAutoAlert);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).localizeBackendMessage(res['message'], fallback: AppLocalizations.of(context).failedToUpdateAlertPref)),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  Future<void> _deleteContact(EmergencyContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).deleteContactTitle, style: const TextStyle(color: Color(0xFF1B1B1C))),
        content: Text(
          AppLocalizations.of(context).deleteContactConfirmVal(contact.name),
          style: const TextStyle(color: _onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context).cancel, style: const TextStyle(color: _onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await _contactService.deleteContact(contact.id);

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _contacts.removeWhere((c) => c.id == contact.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).localizeBackendMessage(res['message'], fallback: AppLocalizations.of(context).contactDeletedSuccess)),
          backgroundColor: _primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).localizeBackendMessage(res['message'], fallback: AppLocalizations.of(context).failedToDeleteContact)),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: RefreshIndicator(
        onRefresh: _loadContacts,
        color: _primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section Header ───────────────────────────────────
              _buildSectionHeader(context),
              const SizedBox(height: 24),

              // ── State Handling ───────────────────────────────────
              if (_isLoading)
                _buildLoadingState()
              else if (_errorMessage != null)
                _buildErrorState()
              else if (_contacts.isEmpty)
                _buildEmptyState(context)
              else
                _buildContactsList(),

            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Section Header
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).contactsHeading,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                AppLocalizations.of(context).manageCircleOfSafety,
                style: const TextStyle(
                  fontSize: 14,
                  color: _onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Add New button
        GestureDetector(
          onTap: () => _showAddEditContactSheet(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).addNew,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Loading State
  // ─────────────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: CircularProgressIndicator(
          color: _primary,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Error State
  // ─────────────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF8B4B4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFF9B1C1C)),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).unableToLoadContacts,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9B1C1C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? AppLocalizations.of(context).errorFetchingContacts,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF771D1D)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadContacts,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(AppLocalizations.of(context).retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Empty State
  // ─────────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _secondaryContainer,
            ),
            child: const Icon(
              Icons.contact_phone_outlined,
              size: 32,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noEmergencyContactsYet,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1B1C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).noContactsDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: _onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddEditContactSheet(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(AppLocalizations.of(context).addFirstContact),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Contacts List
  // ─────────────────────────────────────────────────────────────────
  Widget _buildContactsList() {
    return Column(
      children: _contacts.asMap().entries.map((entry) {
        final i = entry.key;
        final contact = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: i < _contacts.length - 1 ? 14 : 0),
          child: _ContactCard(
            contact: contact,
            onToggleChanged: (val) => _toggleAutoAlert(contact, val),
            onEdit: () => _showAddEditContactSheet(context, contact: contact),
            onDelete: () => _deleteContact(contact),
          ),
        );
      }).toList(),
    );
  }


  // ─────────────────────────────────────────────────────────────────
  //  Add/Edit Contact Bottom Sheet
  // ─────────────────────────────────────────────────────────────────
  void _showAddEditContactSheet(BuildContext context, {EmergencyContactModel? contact}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditContactSheet(
        contact: contact,
        onSaved: _loadContacts,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Contact Card
// ─────────────────────────────────────────────────────────────────
class _ContactCard extends StatefulWidget {
  final EmergencyContactModel contact;
  final ValueChanged<bool> onToggleChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.onToggleChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  bool _hovered = false;

  static const Color _primary = Color(0xFF301427);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _outlineBase = Color(0xFF301427);
  static const Color _outlineActive = Color(0xFF785369);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _toggleActive = Color(0xFFD8C0CB);
  static const Color _toggleInactive = Color(0xFFE4E2E3);

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.contact.autoAlert
        ? _outlineActive.withOpacity(0.4)
        : _outlineBase.withOpacity(0.1);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(_hovered ? 0.10 : 0.04),
              blurRadius: _hovered ? 20 : 6,
              spreadRadius: _hovered ? -4 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Avatar ──────────────────────────────────────────
            _buildAvatar(),
            const SizedBox(width: 14),

            // ── Name + Phone + Relationship ──────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.contact.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.contact.relationship.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _secondaryContainer.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.contact.relationship,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.contact.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // ── Quick Actions (Edit / Delete) ───────────────────
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: _onSurfaceVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'edit') widget.onEdit();
                if (val == 'delete') widget.onDelete();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18, color: _primary),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).editContact, style: const TextStyle(fontSize: 13.5)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).delete, style: const TextStyle(fontSize: 13.5, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),

            // ── Auto-alert Toggle ────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppLocalizations.of(context).autoAlertBadge,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                _NirbhayToggle(
                  value: widget.contact.autoAlert,
                  activeColor: _toggleActive,
                  inactiveColor: _toggleInactive,
                  onChanged: widget.onToggleChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.contact.avatarColor,
        border: Border.all(color: _secondaryContainer, width: 2),
      ),
      child: Center(
        child: Text(
          widget.contact.initials,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _primary.withOpacity(0.85),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Custom Toggle Switch (matches HTML slider style)
// ─────────────────────────────────────────────────────────────────
class _NirbhayToggle extends StatelessWidget {
  final bool value;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<bool> onChanged;

  const _NirbhayToggle({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const double w = 44.0;
    const double h = 24.0;
    const double thumbSize = 18.0;
    const double padding = 3.0;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h),
          color: value ? activeColor : inactiveColor,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: padding,
              left: value ? (w - thumbSize - padding) : padding,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Add / Edit Contact Bottom Sheet
// ─────────────────────────────────────────────────────────────────
class _AddEditContactSheet extends StatefulWidget {
  final EmergencyContactModel? contact;
  final VoidCallback onSaved;

  const _AddEditContactSheet({
    this.contact,
    required this.onSaved,
  });

  @override
  State<_AddEditContactSheet> createState() => _AddEditContactSheetState();
}

class _AddEditContactSheetState extends State<_AddEditContactSheet> {
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _outlineVariant = Color(0xFFD1C3C9);
  static const Color _toggleActive = Color(0xFFD8C0CB);
  static const Color _toggleInactive = Color(0xFFE4E2E3);

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _relationshipController;
  late bool _autoAlert;

  bool _isSaving = false;
  String? _sheetError;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phone ?? '');
    _relationshipController = TextEditingController(text: widget.contact?.relationship ?? '');
    _autoAlert = widget.contact?.autoAlert ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _sheetError = null;
    });

    final service = EmergencyContactService();
    final Map<String, dynamic> res;

    if (_isEditing) {
      res = await service.updateContact(
        widget.contact!.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        relationship: _relationshipController.text.trim(),
        autoAlert: _autoAlert,
      );
    } else {
      res = await service.addContact(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        relationship: _relationshipController.text.trim(),
        autoAlert: _autoAlert,
      );
    }

    if (!mounted) return;

    if (res['success'] == true) {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).localizeBackendMessage(res['message'], fallback: AppLocalizations.of(context).contactSavedSuccess)),
          backgroundColor: _primary,
        ),
      );
    } else {
      setState(() {
        _isSaving = false;
        _sheetError = AppLocalizations.of(context).localizeBackendMessage(res['message'] as String?, fallback: AppLocalizations.of(context).failedToSaveContact);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              _isEditing ? AppLocalizations.of(context).editEmergencyContact : AppLocalizations.of(context).addEmergencyContact,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
            const SizedBox(height: 16),

            if (_sheetError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF8B4B4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFF9B1C1C), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sheetError!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF9B1C1C)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            _sheetField(
              controller: _nameController,
              label: AppLocalizations.of(context).fullNameAsterisk,
              hint: AppLocalizations.of(context).fullNameHint,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return AppLocalizations.of(context).pleaseEnterContactName;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            _sheetField(
              controller: _phoneController,
              label: AppLocalizations.of(context).phoneNumberAsterisk,
              hint: AppLocalizations.of(context).phoneNumberHint,
              keyboardType: TextInputType.phone,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return AppLocalizations.of(context).pleaseEnterPhoneNumber;
                }
                if (val.trim().length < 7) {
                  return AppLocalizations.of(context).pleaseEnterValidPhoneNumber;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            _sheetField(
              controller: _relationshipController,
              label: AppLocalizations.of(context).relationshipOptional,
              hint: AppLocalizations.of(context).relationshipHint,
            ),
            const SizedBox(height: 16),

            // Auto alert setting row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).automaticSosAlert,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1B1C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).alertContactDuringEmergencies,
                      style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                    ),
                  ],
                ),
                _NirbhayToggle(
                  value: _autoAlert,
                  activeColor: _toggleActive,
                  inactiveColor: _toggleInactive,
                  onChanged: (val) => setState(() => _autoAlert = val),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _isEditing ? AppLocalizations.of(context).updateContact : AppLocalizations.of(context).saveContact,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B1B1C),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _onSurfaceVariant, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
