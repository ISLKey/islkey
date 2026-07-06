/// Canonical ISL error-code catalog — shared, identical across ALL ISL apps
/// (ISLShift, ISLKey, and future apps). Keep this map byte-for-byte in sync
/// with ISL_Errors (isl-core) on the server. Codes map to user-facing text.
class IslErrorCodes {
  static const Map<String, String> messages = {
    'ERR-01': 'This site is unavailable. Please contact your system manager.',
    'ERR-02': 'This site is unavailable. Please contact your system manager.',
    'ERR-03': 'This site is unavailable. Please contact your system manager.',
    'ERR-04': 'Your account is inactive. Please contact your system manager.',
    'ERR-05': 'You are not authorised at this site. Please contact your system manager.',
    'ERR-06': 'This tag is not recognised. Please contact your system manager.',
    'ERR-07': 'This site is unavailable. Please contact your system manager.',
    'ERR-08': 'Incorrect details. Please try again.',
    'ERR-09': 'This setup code is invalid or has expired. Please ask your manager for a new invitation.',
    'ERR-10': 'Wrong tag for this action. Please contact your system manager.',
    'ERR-11': 'Your access has been frozen. Please contact your system manager.',
    'ERR-12': 'Your access has been removed. Please contact your system manager.',
  };

  /// Returns the mapped message for a code, or null if the code is unknown/null.
  static String? messageFor(String? code) =>
      code == null ? null : messages[code];
}
