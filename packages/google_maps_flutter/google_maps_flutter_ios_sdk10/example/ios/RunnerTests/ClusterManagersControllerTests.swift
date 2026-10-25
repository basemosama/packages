// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Flutter
import GoogleMaps
import Testing

@testable import google_maps_flutter_ios_sdk10

@MainActor struct ClusterManagersControllerTests {

  @Test func clustering() throws {
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

    let mapViewOptions = GMSMapViewOptions()
    mapViewOptions.frame = frame
    mapViewOptions.camera = GMSCameraPosition(latitude: 0, longitude: 0, zoom: 0)

    let mapView = PartiallyMockedMapView(options: mapViewOptions)
    let eventHandler = TestMapEventHandler()

    let clusterManagersController = ClusterManagersController(
      mapView: mapView,
      eventDelegate: eventHandler
    )

    let markersController = MarkersController(
      mapView: mapView,
      eventDelegate: eventHandler,
      clusterManagersController: clusterManagersController,
      assetProvider: TestAssetProvider(),
      markerType: .marker
    )

    // Add cluster managers.
    let clusterManagerId = "cm"
    let clusterManagerToAdd = PlatformClusterManager(identifier: clusterManagerId)
    clusterManagersController.add([clusterManagerToAdd])

    // Verify that cluster managers are available
    var clusterManager = clusterManagersController.clusterManager(withIdentifier: clusterManagerId)
    #expect(clusterManager != nil)

    // Add markers
    let markerId1 = "m1"
    let markerId2 = "m2"

    let zeroPoint = PlatformPoint(x: 0, y: 0)
    let zeroLatLng = PlatformLatLng(latitude: 0, longitude: 0)
    let bitmap = PlatformBitmapDefaultMarker(hue: 0)
    let infoWindow = PlatformInfoWindow(
      title: "Info",
      snippet: nil,
      anchor: zeroPoint
    )
    let marker1 = PlatformMarker(
      alpha: 1,
      anchor: zeroPoint,
      consumeTapEvents: false,
      draggable: false,
      flat: false,
      icon: bitmap,
      infoWindow: infoWindow,
      position: zeroLatLng,
      rotation: 0,
      visible: true,
      zIndex: 1,
      markerId: markerId1,
      clusterManagerId: clusterManagerId,
      collisionBehavior: nil
    )
    let marker2 = PlatformMarker(
      alpha: 1,
      anchor: zeroPoint,
      consumeTapEvents: false,
      draggable: false,
      flat: false,
      icon: bitmap,
      infoWindow: infoWindow,
      position: zeroLatLng,
      rotation: 0,
      visible: true,
      zIndex: 1,
      markerId: markerId2,
      clusterManagerId: clusterManagerId,
      collisionBehavior: nil
    )

    markersController.add([marker1, marker2])

    // Invoke clustering
    clusterManagersController.invokeClusteringForEachClusterManager()

    // Verify that the markers were added to the cluster manager
    let clusters1 = try clusterManagersController.clusters(withIdentifier: clusterManagerId)
    let targetCluster = try #require(
      clusters1.first(where: { $0.clusterManagerId == clusterManagerId })
    )
    #expect(targetCluster.markerIds.count == 2)
    #expect(targetCluster.markerIds.contains(markerId1))
    #expect(targetCluster.markerIds.contains(markerId2))

    markersController.removeMarkers(withIdentifiers: [markerId2])

    // Verify that the marker2 is removed from the clusterManager
    let clusters2 = try clusterManagersController.clusters(withIdentifier: clusterManagerId)
    let targetCluster2 = try #require(
      clusters2.first(where: { $0.clusterManagerId == clusterManagerId })
    )
    #expect(targetCluster2.markerIds.count == 1)
    #expect(targetCluster2.markerIds.contains(markerId1))

    markersController.removeMarkers(withIdentifiers: [markerId1])

    // Verify that all markers are removed from clusterManager
    let clusters3 = try clusterManagersController.clusters(withIdentifier: clusterManagerId)
    #expect(clusters3.count == 0)

    // Remove cluster manager
    clusterManagersController.removeClusterManagers(withIdentifiers: [clusterManagerId])

    // Verify that the cluster manager is removed
    clusterManager = clusterManagersController.clusterManager(withIdentifier: clusterManagerId)
    #expect(clusterManager == nil)
  }

  private func makeControllers() -> (
    ClusterManagersController, MarkersController, TestMapEventHandler, GMSMapView
  ) {
    let mapViewOptions = GMSMapViewOptions()
    mapViewOptions.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    mapViewOptions.camera = GMSCameraPosition(latitude: 0, longitude: 0, zoom: 0)
    let mapView = PartiallyMockedMapView(options: mapViewOptions)
    let eventHandler = TestMapEventHandler()
    let clusterManagersController = ClusterManagersController(
      mapView: mapView,
      eventDelegate: eventHandler
    )
    let markersController = MarkersController(
      mapView: mapView,
      eventDelegate: eventHandler,
      clusterManagersController: clusterManagersController,
      assetProvider: TestAssetProvider(),
      markerType: .marker
    )
    return (clusterManagersController, markersController, eventHandler, mapView)
  }

  private func makeMarker(
    _ markerId: String, clusterManagerId: String, latitude: Double, longitude: Double
  ) -> PlatformMarker {
    let zeroPoint = PlatformPoint(x: 0, y: 0)
    return PlatformMarker(
      alpha: 1,
      anchor: zeroPoint,
      consumeTapEvents: false,
      draggable: false,
      flat: false,
      icon: PlatformBitmapDefaultMarker(hue: 0),
      infoWindow: PlatformInfoWindow(title: nil, snippet: nil, anchor: zeroPoint),
      position: PlatformLatLng(latitude: latitude, longitude: longitude),
      rotation: 0,
      visible: true,
      zIndex: 1,
      markerId: markerId,
      clusterManagerId: clusterManagerId,
      collisionBehavior: nil
    )
  }

  @Test func movingClusteredMarkerUpdatesClusters() throws {
    // The controllers only hold weak references to the map view.
    let (clusterManagersController, markersController, _, mapView) = makeControllers()
    // At low zoom levels every item is within clustering distance of every other, which would
    // hide a stale position.
    mapView.camera = GMSCameraPosition(latitude: 0, longitude: 0, zoom: 10)
    defer { withExtendedLifetime(mapView) {} }
    let clusterManagerId = "cm"
    clusterManagersController.add([PlatformClusterManager(identifier: clusterManagerId)])
    markersController.add([
      makeMarker("m1", clusterManagerId: clusterManagerId, latitude: 0, longitude: 0)
    ])
    clusterManagersController.invokeClusteringForEachClusterManager()

    // Moving a clustered marker previously left a stale entry in the clustering algorithm, which
    // made the next clustering pass fail.
    markersController.change([
      makeMarker("m1", clusterManagerId: clusterManagerId, latitude: 10, longitude: 20)
    ])
    clusterManagersController.invokeClusteringForEachClusterManager()

    let clusters = try clusterManagersController.clusters(withIdentifier: clusterManagerId)
    let cluster = try #require(clusters.first)
    #expect(clusters.count == 1)
    #expect(cluster.markerIds == ["m1"])
    #expect(cluster.position.latitude == 10)
    #expect(cluster.position.longitude == 20)
  }

  @Test func sendsClusterUpdates() async throws {
    let (clusterManagersController, markersController, eventHandler, mapView) = makeControllers()
    var updates = eventHandler.clusterUpdates.makeAsyncIterator()
    let clusterManagerId = "cm"
    clusterManagersController.add([PlatformClusterManager(identifier: clusterManagerId)])
    markersController.add([
      makeMarker("m1", clusterManagerId: clusterManagerId, latitude: 0, longitude: 0)
    ])

    clusterManagersController.invokeClusteringForEachClusterManager()
    #expect(await updates.next() == clusterManagerId)

    // No update while the integral zoom level is unchanged.
    mapView.camera = GMSCameraPosition(latitude: 0, longitude: 0, zoom: 0.4)
    clusterManagersController.didIdleCamera()

    mapView.camera = GMSCameraPosition(latitude: 0, longitude: 0, zoom: 5)
    clusterManagersController.didIdleCamera()
    #expect(await updates.next() == clusterManagerId)
    #expect(eventHandler.clusterUpdateCount == 2)
  }
}
