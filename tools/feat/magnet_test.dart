// Quick smoke test for the magnet URI parser.
import 'package:velocita_kernel/velocita_kernel.dart';

void main() {
  final magnet = parseMagnet(
    'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Fexplodie.org%3A6969&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969&ws=https%3A%2F%2Fwebseed.bbtvdl.de%2Fbbb',
  );
  print('displayName: ${magnet.displayName}');
  print('btihHash: ${magnet.btihHash}');
  print('trackers: ${magnet.trackers}');
  print('webSeeds: ${magnet.webSeeds}');
  print('hasBtih: ${magnet.hasBtih}');

  final empty = parseMagnet('magnet:?xt=urn:btih:abc&dn=test');
  print('---empty trackers---');
  print('trackers: ${empty.trackers}');
}
