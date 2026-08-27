abstract final class AppFormatters {
  static const _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String date(DateTime value) {
    return '${_months[value.month - 1]} ${value.day}, ${value.year}';
  }

  static String time(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  static String coordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  static String percentage(double value) => '${(value * 100).round()}%';
}
