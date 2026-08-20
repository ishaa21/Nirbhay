import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Full-screen map background
        Positioned.fill(
          child: Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuCMNpoYuUMwvEnFQqv9iFS7jmGSEAb7Sr7BlZKYtsI4GXDyXhWxc-ZZ6wpIz4Hsw9g9D7oQkcWUR1_fyyZqi5bmrXYbH1nZspCzZBt_J82Z1FCec9qfsAigv9N_c2MQ8QZy6h03WHqoQGoib8DdpQ3xEOythfuxhtKH3lusXv9baA96J8lxzlMeYUJp5c42nRepht63An0WKi1uxLw9Om20cvDTQrjtCR_byMoZnEyO56i5xP6-b8NraOxy0nNdjGqY-YrLTe9rHjQ8',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFFF0EBE8),
                child: const Center(
                  child: Icon(Icons.map, size: 48, color: Colors.grey),
                ),
              );
            },
          ),
        ),

        // Map overlay gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFCF8F9).withOpacity(0.9),
                  const Color(0xFFFCF8F9).withOpacity(0.0),
                ],
                stops: const [0.0, 0.2],
              ),
            ),
          ),
        ),

        // 2. Mock Markers
        // Marker 1: Police (Safe Zone)
        Positioned(
          top: 150,
          left: 180,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF301427), // _accent
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                child: const Icon(Icons.local_police, color: Colors.white, size: 16),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD1C3C9)),
                ),
                child: const Text(
                  'Safe Zone',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF301427)),
                ),
              )
            ],
          ),
        ),

        // Marker 2: Medical
        Positioned(
          top: 280,
          left: 90,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF002035), // tertiary
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.medical_services, color: Colors.white, size: 16),
          ),
        ),

        // 3. Search Bar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1C3C9).withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF807479)),
                const SizedBox(width: 8),
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search safe destinations',
                      hintStyle: TextStyle(color: Color(0xFFD1C3C9), fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.mic, color: Color(0xFF301427)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
          ),
        ),

        // 4. Floating Action Button: User Location
        Positioned(
          bottom: 120, // positioned above the collapsed sheet
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF301427),
            onPressed: () {},
            child: const Icon(Icons.my_location),
          ),
        ),

        // 5. Draggable Bottom Sheet
        Positioned.fill(
          child: _buildDraggableBottomSheet(),
        ),
      ],
    );
  }

  Widget _buildDraggableBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.8,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1C3C9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nearby Safe Zones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF301427), // _accent
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Filters (Horizontal Scroll)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildFilterChip('Police Stations', Icons.local_police, true),
                    const SizedBox(width: 8),
                    _buildFilterChip('Medical Help', Icons.medical_services, false),
                    const SizedBox(width: 8),
                    _buildFilterChip('Open Shops', Icons.store, false),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Safe Zones List
              _buildSafeZoneItem(
                title: 'Parliament St. Police Station',
                distance: '0.4 km away',
                status: 'Safe Now',
                isSafe: true,
                icon: Icons.local_police,
                iconBg: const Color(0xFF301427).withOpacity(0.1),
                iconColor: const Color(0xFF301427),
              ),
              const SizedBox(height: 12),
              _buildSafeZoneItem(
                title: 'AIIMS Emergency Center',
                distance: '1.2 km away',
                status: '24/7 Open',
                isSafe: false,
                icon: Icons.medical_services,
                iconBg: const Color(0xFF002035).withOpacity(0.1),
                iconColor: const Color(0xFF002035),
              ),
              const SizedBox(height: 80), // extra padding for bottom nav space
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF301427) : const Color(0xFFF2D9E4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : const Color(0xFF705D67),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF705D67),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeZoneItem({
    required String title,
    required String distance,
    required String status,
    required bool isSafe,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1C3C9).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1B1C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          distance,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF807479)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFD1C3C9),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSafe ? const Color(0xFF059669) : const Color(0xFF705D67),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.favorite_border, color: Color(0xFF807479), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF301427),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.directions, size: 14),
                  label: const Text('Directions', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF705D67),
                  side: const BorderSide(color: Color(0xFFF2D9E4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () {},
                child: const Text('Call', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
