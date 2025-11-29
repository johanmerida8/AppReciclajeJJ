# 🔔 Real-Time Notification System Guide

## Overview
All three notification screens now have:
- ✅ **Real-time updates** via Supabase listeners
- ✅ **Local read tracking** using SharedPreferences
- ✅ **Automatic badge reset** when opening notifications
- ✅ **No database modifications needed**

## How It Works

### 1. Real-Time Listeners
Each screen subscribes to Supabase real-time changes:
- **Distributor**: Listens to `request` table changes
- **Company**: Listens to `request` table changes
- **Employee**: Listens to `tasks` table changes

When data changes (insert/update/delete), the notification list refreshes automatically.

### 2. Local Read Tracking
Uses SharedPreferences to store read notification IDs:
- `read_distributor_notifications` - List of read request IDs
- `read_company_notifications` - List of read request IDs
- `read_employee_notifications` - List of read task IDs

When user opens the notification screen, all current notifications are marked as read locally.

### 3. Badge Count Logic
Each screen has a static `getUnreadCount()` method that:
1. Fetches all relevant notifications from Supabase
2. Filters out notifications already in the local read list
3. Returns the count of unread notifications

## Usage in Your UI

### Example: Display Badge in Navigation
```dart
class YourNavigationWidget extends StatefulWidget {
  @override
  State<YourNavigationWidget> createState() => _YourNavigationWidgetState();
}

class _YourNavigationWidgetState extends State<YourNavigationWidget> {
  int _notificationCount = 0;
  int? _userId; // or _employeeId, or _companyId depending on role

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
    _setupPeriodicRefresh();
  }

  Future<void> _loadNotificationCount() async {
    // For Distributor
    final count = await NotificationsScreen.getUnreadCount(_userId);
    
    // For Company
    // final count = await CompanyNotificationsScreen.getUnreadCount(_companyId);
    
    // For Employee
    // final count = await EmployeeNotificationsScreen.getUnreadCount(_employeeId);
    
    if (mounted) {
      setState(() {
        _notificationCount = count;
      });
    }
  }

  void _setupPeriodicRefresh() {
    // Refresh badge count every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadNotificationCount();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        label: Text('$_notificationCount'),
        isLabelVisible: _notificationCount > 0,
        child: const Icon(Icons.notifications),
      ),
      onPressed: () async {
        // Navigate to notifications
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationsScreen(),
          ),
        );
        
        // Refresh count after returning
        _loadNotificationCount();
      },
    );
  }
}
```

### Example: Status Indicators Widget Update
```dart
// In status_indicator.dart or wherever you display the bell icon

class StatusIndicators extends StatefulWidget {
  final int? userId; // Add this parameter
  // ... other parameters
}

class _StatusIndicatorsState extends State<StatusIndicators> {
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBadgeCount();
  }

  Future<void> _loadBadgeCount() async {
    final count = await NotificationsScreen.getUnreadCount(widget.userId);
    if (mounted) {
      setState(() {
        _notificationCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ... connection and GPS badges
        
        // Notification button with badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: widget.onNotificationTap,
              icon: const Icon(Icons.notifications),
            ),
            if (_notificationCount > 0)
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
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$_notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
```

## Static Methods Available

### Distributor
```dart
static Future<int> getUnreadCount(int? userId)
```
- Returns count of unread pending requests for distributor's articles

### Company
```dart
static Future<int> getUnreadCount(int? companyId)
```
- Returns count of unread approved/rejected requests for the company

### Employee
```dart
static Future<int> getUnreadCount(int? employeeId)
```
- Returns count of unread assigned tasks for the employee

## Behavior Flow

### When User Opens Notifications:
1. `initState()` loads notifications from database
2. `_setupRealtimeListener()` subscribes to changes
3. `_markAllAsReadLocally()` adds all current notification IDs to local storage
4. Badge count updates automatically when they return to previous screen

### When New Notification Arrives:
1. Real-time listener detects change
2. `_loadNotifications()` refreshes the list
3. New notification is NOT in local read list
4. Badge count increases automatically
5. When user opens notifications, new items are marked as read

### When User Returns to App:
1. Badge count is recalculated from stored read list
2. Only truly new notifications (not in read list) show in badge
3. No server requests needed for read status

## Data Persistence

### SharedPreferences Keys:
- `read_distributor_notifications`: `List<String>` of request IDs
- `read_company_notifications`: `List<String>` of request IDs
- `read_employee_notifications`: `List<String>` of task IDs

### To Clear Read History (if needed):
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.remove('read_distributor_notifications');
await prefs.remove('read_company_notifications');
await prefs.remove('read_employee_notifications');
```

## Performance Notes

1. **No Database Schema Changes**: Everything is local, no migrations needed
2. **Efficient Queries**: Only fetches IDs for counting, not full notification data
3. **Auto-Cleanup**: Read list grows but only contains IDs (small data)
4. **Real-Time**: Supabase handles push notifications efficiently

## Testing Checklist

- [ ] Badge shows correct count on initial load
- [ ] Badge updates when new notification arrives (test with 2 devices)
- [ ] Badge resets to 0 when opening notifications
- [ ] Badge persists across app restarts
- [ ] Real-time updates work without manual refresh
- [ ] Multiple users don't interfere with each other's read status
- [ ] Works offline (uses cached read list)

## Future Enhancements (Optional)

1. **Cleanup old read IDs**: Remove IDs older than 30 days
2. **Badge animation**: Pulse effect when new notification arrives
3. **Sound/vibration**: Play notification sound on new items
4. **Push notifications**: Use FCM for background notifications
5. **Notification grouping**: Group by date (today, yesterday, older)
