import 'package:flutter/material.dart';

class StatusIndicators extends StatelessWidget {
  final bool isDeviceConnected;
  final bool isLocationServiceEnabled;
  final bool hasLocationPermission;
  final bool hasCheckedLocation;
  final VoidCallback onGpsTap;
  final VoidCallback onRefreshTap;
  final VoidCallback? onNotificationTap;
  final int notificationCount;

  const StatusIndicators({
    Key? key,
    required this.isDeviceConnected,
    required this.isLocationServiceEnabled,
    required this.hasLocationPermission,
    required this.hasCheckedLocation,
    required this.onGpsTap,
    required this.onRefreshTap,
    this.onNotificationTap,
    this.notificationCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Connection indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDeviceConnected
                ? Colors.green.withOpacity(0.8)
                : Colors.red.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDeviceConnected ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                isDeviceConnected ? 'En línea' : 'Sin conexión',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // GPS Status Indicator
        if (hasCheckedLocation) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onGpsTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isLocationServiceEnabled && hasLocationPermission)
                    ? Colors.blue.withOpacity(0.8)
                    : Colors.orange.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (isLocationServiceEnabled && hasLocationPermission)
                        ? Icons.location_on
                        : Icons.location_off,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (isLocationServiceEnabled && hasLocationPermission)
                        ? 'GPS OK'
                        : 'GPS OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const Spacer(),

        // Refresh button
        IconButton(
          onPressed: isDeviceConnected ? onRefreshTap : null,
          icon: Icon(
            Icons.refresh,
            color: isDeviceConnected ? Colors.white : Colors.white54,
          ),
          tooltip: isDeviceConnected ? 'Actualizar datos' : 'Sin conexión',
        ),

        // Notification button
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onNotificationTap,
              icon: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2D8A8A),
                      width: 2,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.notifications,
                      color: Color(0xFF2D8A8A),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            if (notificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      notificationCount > 9 ? '9+' : '$notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}