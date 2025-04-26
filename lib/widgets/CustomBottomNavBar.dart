import 'package:flutter/material.dart';


class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final Function(BuildContext) onScanTapped;
  final Function(BuildContext) onCommunityTapped;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTabTapped,
    required this.onScanTapped,
    required this.onCommunityTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == 1) {
          onScanTapped(context);
        } else if (index == 2) {
          onCommunityTapped(context);
        } else {
          onTabTapped(index);
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.groups),
          label: 'Community',
        ),
      ],
    );
  }
}
