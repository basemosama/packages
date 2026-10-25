// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'fake_google_maps_flutter_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGoogleMapsFlutterPlatform platform;

  const clusterManagerId = ClusterManagerId('cm-1');
  final cluster = Cluster(
    clusterManagerId,
    const <MarkerId>[MarkerId('marker-1')],
    position: const LatLng(1.0, 2.0),
    bounds: LatLngBounds(southwest: const LatLng(0.0, 0.0), northeast: const LatLng(2.0, 3.0)),
  );

  setUp(() {
    platform = FakeGoogleMapsFlutterPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });

  Widget mapWithClusterManagers(
    Set<ClusterManager> clusterManagers, {
    void Function(ClusterManagerId, List<Cluster>)? onClusterManagerUpdated,
    ValueChanged<GoogleMapController>? onMapCreated,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GoogleMap(
        initialCameraPosition: const CameraPosition(target: LatLng(0.0, 0.0)),
        clusterManagers: clusterManagers,
        onClusterManagerUpdated: onClusterManagerUpdated,
        onMapCreated: onMapCreated,
      ),
    );
  }

  testWidgets('cluster updates are forwarded to both callbacks', (WidgetTester tester) async {
    List<Cluster>? managerClusters;
    ClusterManagerId? widgetClusterManagerId;
    List<Cluster>? widgetClusters;

    await tester.pumpWidget(
      mapWithClusterManagers(
        <ClusterManager>{
          ClusterManager(
            clusterManagerId: clusterManagerId,
            onClustersUpdated: (List<Cluster> clusters) => managerClusters = clusters,
          ),
        },
        onClusterManagerUpdated: (ClusterManagerId id, List<Cluster> clusters) {
          widgetClusterManagerId = id;
          widgetClusters = clusters;
        },
      ),
    );
    await tester.pump();

    final int mapId = platform.createdIds.first;
    platform.mapEventStreamController.add(
      ClusterManagerUpdateEvent(mapId, <Cluster>[cluster], clusterManagerId: clusterManagerId),
    );
    await tester.pump();

    expect(managerClusters, <Cluster>[cluster]);
    expect(widgetClusterManagerId, clusterManagerId);
    expect(widgetClusters, <Cluster>[cluster]);
  });

  testWidgets('updates for unknown cluster managers are ignored', (WidgetTester tester) async {
    var widgetCallbackCalled = false;

    await tester.pumpWidget(
      mapWithClusterManagers(
        const <ClusterManager>{},
        onClusterManagerUpdated: (ClusterManagerId id, List<Cluster> clusters) {
          widgetCallbackCalled = true;
        },
      ),
    );
    await tester.pump();

    final int mapId = platform.createdIds.first;
    platform.mapEventStreamController.add(
      ClusterManagerUpdateEvent(mapId, <Cluster>[cluster], clusterManagerId: clusterManagerId),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(widgetCallbackCalled, isFalse);
  });

  testWidgets('getClusters returns clusters from the platform', (WidgetTester tester) async {
    GoogleMapController? controller;
    platform.clusters[clusterManagerId] = <Cluster>[cluster];

    await tester.pumpWidget(
      mapWithClusterManagers(<ClusterManager>{
        const ClusterManager(clusterManagerId: clusterManagerId),
      }, onMapCreated: (GoogleMapController c) => controller = c),
    );
    await tester.pump();

    expect(await controller!.getClusters(clusterManagerId), <Cluster>[cluster]);
  });
}
