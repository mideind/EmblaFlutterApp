// @dart=2.9
// ^ Removes checks for null safety
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import './common.dart';

final List<RegExp> kmDNSServiceFilters = <RegExp>[
  RegExp(r"_hue._tcp.local"),
  RegExp(r"_sonos._tcp.local"),
];

/// Dataclass for storing information about a discovered device.
class MDNSDevice {
  String fqdn; // Fully qualified domain name
  String ip; // IP address
  int port; // Port
  MDNSDevice({this.fqdn, this.ip, this.port});
}

/// Class for handling mDNS queries.
class MulticastDNSSearcher {
  // Magic address for finding services on local network
  static const String _endpoint = '_services._dns-sd._udp.local';
  MDnsClient _client;

  /// Private constructor for singleton class.
  /// Creates an MDnsClient (turn off reusePort, due to bug on some devices).
  MulticastDNSSearcher() {
    _client = MDnsClient(
        rawDatagramSocketFactory: (
      dynamic host,
      int port, {
      bool reuseAddress,
      bool reusePort,
      int ttl,
    }) =>
            RawDatagramSocket.bind(host, port,
                reuseAddress: true, reusePort: false, ttl: ttl));
  }

  // NULL SAFE VERSION
  //   final MDnsClient client = MDnsClient(rawDatagramSocketFactory:
  //     (dynamic host, int port,
  //         {bool? reuseAddress, bool? reusePort, int? ttl}) {
  //   return RawDatagramSocket.bind(host, port,
  //       reuseAddress: true, reusePort: false, ttl: ttl!);
  // });

  /// Finds all devices on the local network using mDNS.
  /// Calls deviceCallback for each found device that matches a filter regex.
  Future<void> findLocalDevices(
      List<RegExp> filters, Function deviceCallback) async {
    // Start the client with default options.
    await _client.start();
    dlog("Started mDNS client");
    // Get the PTR record for the service.
    await for (final PtrResourceRecord ptr in _client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_endpoint))) {
      // Use the domainName from the PTR record to get the SRV record,
      // which will have the port and local hostname.
      // Note that duplicate messages may come through, especially if any
      // other mDNS queries are running elsewhere on the machine.
      dlog('>>>>>>>>>>>>>>> ${ptr.domainName}');
      dlog(ptr);
      for (final RegExp filter in filters) {
        if (filter.hasMatch(ptr.domainName)) {
          await for (final PtrResourceRecord ptr2
              in _client.lookup<PtrResourceRecord>(
                  ResourceRecordQuery.serverPointer(ptr.domainName))) {
            dlog("!!!!!!!!!!!!!!! ${ptr2.domainName}");

            await for (final SrvResourceRecord srv
                in _client.lookup<SrvResourceRecord>(
                    ResourceRecordQuery.service(ptr2.domainName))) {
              dlog(
                  'Something found at ${srv.target}:${srv.port} for "${srv.name}".');
              await for (final IPAddressResourceRecord ipa
                  in _client.lookup<IPAddressResourceRecord>(
                      ResourceRecordQuery.addressIPv4(srv.target))) {
                dlog('IP address is ${ipa.address.address}:${srv.port}');
                // Check if this device matches any of the filters.
                dlog('Device matches filter "${filter.pattern}".');
                // Call the callback with the device info.
                deviceCallback(srv.name, ptr.domainName);
              }
            }
          }
        }
      }
    }
    dlog("Finished searching for devices");
    _client.stop();
    dlog('mDNS client stopped.');
  }
}
