/// Money is stored in paise (integers). Display uses Indian digit grouping: Rs 2,74,990.
String rupees(num paise) {
  final negative = paise < 0;
  final abs = paise.abs().round();
  final whole = abs ~/ 100;
  final frac = abs % 100;
  final s = whole.toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  final fraction = frac == 0 ? '' : '.${frac.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₹$grouped$fraction';
}

int discountPercent(int mrpPaise, int pricePaise) => mrpPaise > pricePaise ? ((mrpPaise - pricePaise) * 100 ~/ mrpPaise) : 0;

String warrantyLabel(int months) => months > 0 && months % 12 == 0 ? '${months ~/ 12} year warranty' : '$months month warranty';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDateTime(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final ap = l.hour >= 12 ? 'PM' : 'AM';
  return '${l.day} ${_months[l.month - 1]} ${l.year}, $h:${l.minute.toString().padLeft(2, '0')} $ap';
}

String formatDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
