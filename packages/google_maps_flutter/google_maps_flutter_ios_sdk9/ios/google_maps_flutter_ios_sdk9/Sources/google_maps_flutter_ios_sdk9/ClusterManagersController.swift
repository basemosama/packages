// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Flutter
import GoogleMaps
import GoogleMapsUtils

/// A controller that manages all of the cluster managers on a map.
class ClusterManagersController {
  private var clusterManagerIdentifierToManagers: [String: GMUClusterManager] = [:]
  /// The integral zoom level at which clusters were last sent to Dart, per cluster manager.
  private var clusterManagerIdentifierToLastUpdateZoom: [String: Float] = [:]
  private weak var eventDelegate: MapEventDelegate?
  private weak var mapView: GMSMapView?

  init(mapView: GMSMapView, eventDelegate: MapEventDelegate) {
    self.mapView = mapView
    self.eventDelegate = eventDelegate
  }

  func add(_ clusterManagersToAdd: [PlatformClusterManager]) {
    for clusterManager in clusterManagersToAdd {
      addClusterManager(clusterManager.identifier)
    }
  }

  func addClusterManager(_ identifier: String) {
    guard let mapView = mapView else { return }
    let algorithm = GMUNonHierarchicalDistanceBasedAlgorithm()
    let iconGenerator = GMUDefaultClusterIconGenerator()
    let renderer = GMUDefaultClusterRenderer(mapView: mapView, clusterIconGenerator: iconGenerator)
    clusterManagerIdentifierToManagers[identifier] = GMUClusterManager(
      map: mapView,
      algorithm: algorithm,
      renderer: renderer
    )
  }

  func removeClusterManagers(withIdentifiers identifiers: [String]) {
    for identifier in identifiers {
      if let clusterManager = clusterManagerIdentifierToManagers[identifier] {
        clusterManager.clearItems()
        clusterManagerIdentifierToManagers.removeValue(forKey: identifier)
        clusterManagerIdentifierToLastUpdateZoom.removeValue(forKey: identifier)
      }
    }
  }

  func clusterManager(withIdentifier identifier: String) -> GMUClusterManager? {
    return clusterManagerIdentifierToManagers[identifier]
  }

  /// Clusters the items of each cluster manager and sends the resulting clusters to Dart.
  func invokeClusteringForEachClusterManager() {
    for (identifier, clusterManager) in clusterManagerIdentifierToManagers {
      clusterManager.cluster()
      sendClusters(withIdentifier: identifier)
    }
  }

  /// Called when the map camera stops moving.
  ///
  /// Sends the clusters of each cluster manager to Dart if the integral zoom level, which
  /// determines the clustering, changed since they were last sent.
  func didIdleCamera() {
    guard let zoom = integralZoom() else { return }
    for (identifier, lastUpdateZoom) in clusterManagerIdentifierToLastUpdateZoom
    where lastUpdateZoom != zoom {
      sendClusters(withIdentifier: identifier)
    }
  }

  func clusters(withIdentifier identifier: String) throws -> [PlatformCluster] {
    guard let clusterManager = clusterManagerIdentifierToManagers[identifier] else {
      throw PigeonError(
        code: "Invalid clusterManagerId",
        message: "getClusters called with invalid clusterManagerId",
        details: "clusterManagerId was: '\(identifier)'"
      )
    }
    guard let integralZoom = integralZoom() else { return [] }
    let clusters = clusterManager.algorithm.clusters(atZoom: integralZoom)
    return clusters.map { PlatformCluster.make(from: $0, clusterManagerIdentifier: identifier) }
  }

  func didTap(_ cluster: GMUStaticCluster) {
    guard let clusterManagerId = clusterManagerIdentifier(for: cluster) else { return }
    let platformCluster = PlatformCluster.make(
      from: cluster, clusterManagerIdentifier: clusterManagerId)
    Task {
      try await eventDelegate?.didTapCluster(platformCluster)
    }
  }

  /// Returns the integral zoom level used for clustering, or nil if the map is gone.
  private func integralZoom() -> Float? {
    guard let mapView = mapView else { return nil }
    // Ref:
    // https://github.com/googlemaps/google-maps-ios-utils/blob/0e7ed81f1bbd9d29e4529c40ae39b0791b0a0eb8/src/Clustering/GMUClusterManager.m#L94.
    return floorf(Float(mapView.camera.zoom) + 0.5)
  }

  /// Sends the current clusters of the cluster manager with the given identifier to Dart.
  private func sendClusters(withIdentifier identifier: String) {
    guard let zoom = integralZoom(),
      let clusters = try? self.clusters(withIdentifier: identifier)
    else { return }
    clusterManagerIdentifierToLastUpdateZoom[identifier] = zoom
    Task {
      try await eventDelegate?.didUpdateClusters(withIdentifier: identifier, clusters: clusters)
    }
  }

  /// Returns the cluster manager identifier for given cluster.
  private func clusterManagerIdentifier(for cluster: GMUStaticCluster) -> String? {
    if let firstMarker = cluster.items.first as? GMSMarker {
      return clusterManagerIdentifierFromMarker(firstMarker)
    }
    return nil
  }
}
