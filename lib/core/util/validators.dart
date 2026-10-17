final _phone = RegExp(r'^[6-9][0-9]{9}$');
final _pin = RegExp(r'^[0-9]{6}$');
final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidPhone(String v) => _phone.hasMatch(v);
bool isValidPincode(String v) => _pin.hasMatch(v);
bool isValidEmail(String v) => _email.hasMatch(v.trim());

String? validateName(String? v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null;
String? validatePhone(String? v) => (v == null || !isValidPhone(v)) ? 'Enter a valid 10-digit mobile number' : null;
String? validatePincode(String? v) => (v == null || !isValidPincode(v)) ? 'Pincode must be 6 digits' : null;
String? validateAddressLine(String? v) => (v == null || v.trim().length < 5) ? 'Enter your house, street and area' : null;
String? validateEmail(String? v) => (v == null || !isValidEmail(v)) ? 'Enter a valid email address' : null;
String? validatePassword(String? v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null;
