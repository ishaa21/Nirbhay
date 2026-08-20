import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
//  Emergency Contacts Screen
// ─────────────────────────────────────────────────────────────────
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // ── Color tokens (match HTML design) ──────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSecondaryContainer = Color(0xFF705D67);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _outlineVariant = Color(0xFFD1C3C9);
  static const Color _toggleActive = Color(0xFFD8C0CB);
  static const Color _toggleInactive = Color(0xFFE4E2E3);

  // ── Contact data ───────────────────────────────────────────────
  final List<_ContactData> _contacts = [
    _ContactData(
      name: 'Jane Doe',
      phone: '+1 (555) 012-3456',
      initials: 'JD',
      avatarColor: Color(0xFFE8C8D8),
      autoAlert: true,
    ),
    _ContactData(
      name: 'Rahul Kumar',
      phone: '+91 98765-43210',
      initials: 'RK',
      avatarColor: Color(0xFFC8D8E8),
      autoAlert: true,
    ),
    _ContactData(
      name: 'Sanya Malhotra',
      phone: '+91 99887-76655',
      initials: 'SM',
      avatarColor: Color(0xFFD8E8C8),
      autoAlert: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header ───────────────────────────────────
            _buildSectionHeader(context),
            const SizedBox(height: 28),

            // ── Contacts List ────────────────────────────────────
            ..._contacts.asMap().entries.map((entry) {
              final i = entry.key;
              final contact = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: i < _contacts.length - 1 ? 14 : 0),
                child: _ContactCard(
                  contact: contact,
                  onToggleChanged: (val) {
                    setState(() => _contacts[i].autoAlert = val);
                  },
                ),
              );
            }),

            const SizedBox(height: 40),

            // ── Info Box ─────────────────────────────────────────
            _buildInfoBox(),
          ],
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
            children: const [
              Text(
                'Emergency Contacts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Manage your circle of safety',
                style: TextStyle(
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
          onTap: () => _showAddContactDialog(context),
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
              children: const [
                Icon(Icons.add, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Add New',
                  style: TextStyle(
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
  //  Info Box
  // ─────────────────────────────────────────────────────────────────
  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 22,
            color: _onSecondaryContainer,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'About Automatic Alerts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _onSecondaryContainer,
                    letterSpacing: 0.1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'When active, your location and a short audio recording are automatically shared with these contacts if an SOS event is triggered or if you fail to check in during a timed walk.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _onSecondaryContainer,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Add Contact Dialog (stub)
  // ─────────────────────────────────────────────────────────────────
  void _showAddContactDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddContactSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Contact Card
// ─────────────────────────────────────────────────────────────────
class _ContactCard extends StatefulWidget {
  final _ContactData contact;
  final ValueChanged<bool> onToggleChanged;

  const _ContactCard({
    required this.contact,
    required this.onToggleChanged,
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

            // ── Name + Phone ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                      letterSpacing: 0.1,
                    ),
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

            // ── Auto-alert Toggle ────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Auto-alert',
                  style: TextStyle(
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.contact.avatarColor,
        border: Border.all(color: _secondaryContainer, width: 2),
      ),
      child: Center(
        child: Text(
          widget.contact.initials,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _primary.withOpacity(0.75),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Custom Toggle Switch  (matches HTML slider style)
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
//  Add Contact Bottom Sheet
// ─────────────────────────────────────────────────────────────────
class _AddContactSheet extends StatelessWidget {
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _outlineVariant = Color(0xFFD1C3C9);

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

          const Text(
            'Add Emergency Contact',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
          const SizedBox(height: 20),

          _sheetField(label: 'Full Name', hint: 'e.g. Jane Doe'),
          const SizedBox(height: 14),
          _sheetField(label: 'Phone Number', hint: 'e.g. +91 98765-43210', keyboardType: TextInputType.phone),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save Contact',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField({
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
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
        TextField(
          keyboardType: keyboardType,
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
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Data Model
// ─────────────────────────────────────────────────────────────────
class _ContactData {
  final String name;
  final String phone;
  final String initials;
  final Color avatarColor;
  bool autoAlert;

  _ContactData({
    required this.name,
    required this.phone,
    required this.initials,
    required this.avatarColor,
    required this.autoAlert,
  });
}
