import 'dart:io';

Future<List<String>> readLocalIpv4Addresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final addresses = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (_isPrivateIpv4(address.address)) {
          addresses.add(address.address);
        }
      }
    }
    return addresses;
  } on Object {
    return const [];
  }
}

bool _isPrivateIpv4(String address) {
  final segments = address.split('.');
  if (segments.length != 4) {
    return false;
  }
  final first = int.tryParse(segments[0]);
  final second = int.tryParse(segments[1]);
  if (first == null || second == null) {
    return false;
  }
  if (first == 10) {
    return true;
  }
  if (first == 172 && second >= 16 && second <= 31) {
    return true;
  }
  return first == 192 && second == 168;
}
