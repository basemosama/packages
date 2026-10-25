// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FGMClusterManagersController.h"

#import "FGMConversionUtils.h"
#import "FGMMarkerUserData.h"

@interface FGMClusterManagersController ()

/// A dictionary mapping unique cluster manager identifiers to their corresponding cluster managers.
@property(strong, nonatomic)
    NSMutableDictionary<NSString *, GMUClusterManager *> *clusterManagerIdentifierToManagers;

/// The delegate for handling interactions with clusters.
@property(weak, nonatomic) NSObject<FGMMapEventDelegate> *eventDelegate;

/// The current map instance on which the cluster managers are operating.
@property(strong, nonatomic) GMSMapView *mapView;

/// The integral zoom level at which clusters were last sent to the event delegate, per cluster
/// manager identifier.
@property(strong, nonatomic)
    NSMutableDictionary<NSString *, NSNumber *> *clusterManagerIdentifierToLastUpdateZoom;

@end

@implementation FGMClusterManagersController
- (instancetype)initWithMapView:(GMSMapView *)mapView
                  eventDelegate:(NSObject<FGMMapEventDelegate> *)eventDelegate {
  self = [super init];
  if (self) {
    _eventDelegate = eventDelegate;
    _mapView = mapView;
    _clusterManagerIdentifierToManagers = [[NSMutableDictionary alloc] init];
    _clusterManagerIdentifierToLastUpdateZoom = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)addClusterManagers:(NSArray<FGMPlatformClusterManager *> *)clusterManagersToAdd {
  for (FGMPlatformClusterManager *clusterManager in clusterManagersToAdd) {
    NSString *identifier = clusterManager.identifier;
    [self addClusterManager:identifier];
  }
}

- (void)addClusterManager:(NSString *)identifier {
  id<GMUClusterAlgorithm> algorithm = [[GMUNonHierarchicalDistanceBasedAlgorithm alloc] init];
  id<GMUClusterIconGenerator> iconGenerator = [[GMUDefaultClusterIconGenerator alloc] init];
  id<GMUClusterRenderer> renderer =
      [[GMUDefaultClusterRenderer alloc] initWithMapView:self.mapView
                                    clusterIconGenerator:iconGenerator];
  self.clusterManagerIdentifierToManagers[identifier] =
      [[GMUClusterManager alloc] initWithMap:self.mapView algorithm:algorithm renderer:renderer];
  ;
}

- (void)removeClusterManagersWithIdentifiers:(NSArray<NSString *> *)identifiers {
  for (NSString *identifier in identifiers) {
    GMUClusterManager *clusterManager =
        [self.clusterManagerIdentifierToManagers objectForKey:identifier];
    if (!clusterManager) {
      continue;
    }
    [clusterManager clearItems];
    [self.clusterManagerIdentifierToManagers removeObjectForKey:identifier];
    [self.clusterManagerIdentifierToLastUpdateZoom removeObjectForKey:identifier];
  }
}

- (nullable GMUClusterManager *)clusterManagerWithIdentifier:(NSString *)identifier {
  return [self.clusterManagerIdentifierToManagers objectForKey:identifier];
}

- (void)invokeClusteringForEachClusterManager {
  for (NSString *identifier in [self.clusterManagerIdentifierToManagers allKeys]) {
    @try {
      [self.clusterManagerIdentifierToManagers[identifier] cluster];
    } @catch (NSException *exception) {
      // GMUNonHierarchicalDistanceBasedAlgorithm asserts when its items become inconsistent. Skip
      // this clustering pass rather than crashing; the next one will retry.
      NSLog(@"Clustering failed for cluster manager '%@': %@", identifier, exception.reason);
      continue;
    }
    [self sendClustersWithIdentifier:identifier];
  }
}

- (void)didIdleCamera {
  NSUInteger integralZoom = [self integralZoom];
  for (NSString *identifier in [self.clusterManagerIdentifierToLastUpdateZoom allKeys]) {
    if (self.clusterManagerIdentifierToLastUpdateZoom[identifier].unsignedIntegerValue !=
        integralZoom) {
      [self sendClustersWithIdentifier:identifier];
    }
  }
}

- (nullable NSArray<FGMPlatformCluster *> *)
    clustersWithIdentifier:(NSString *)identifier
                     error:(FlutterError *_Nullable __autoreleasing *_Nonnull)error {
  GMUClusterManager *clusterManager =
      [self.clusterManagerIdentifierToManagers objectForKey:identifier];

  if (!clusterManager) {
    *error = [FlutterError
        errorWithCode:@"Invalid clusterManagerId"
              message:@"getClusters called with invalid clusterManagerId"
              details:[NSString stringWithFormat:@"clusterManagerId was: '%@'", identifier]];
    return nil;
  }

  NSArray<id<GMUCluster>> *clusters;
  @try {
    clusters = [clusterManager.algorithm clustersAtZoom:[self integralZoom]];
  } @catch (NSException *exception) {
    // See invokeClusteringForEachClusterManager.
    NSLog(@"Getting clusters failed for cluster manager '%@': %@", identifier, exception.reason);
    clusters = @[];
  }
  NSMutableArray<FGMPlatformCluster *> *response =
      [[NSMutableArray alloc] initWithCapacity:clusters.count];
  for (id<GMUCluster> cluster in clusters) {
    FGMPlatformCluster *platFormCluster = FGMGetPigeonCluster(cluster, identifier);
    [response addObject:platFormCluster];
  }
  return response;
}

- (void)didTapCluster:(GMUStaticCluster *)cluster {
  NSString *clusterManagerId = [self clusterManagerIdentifierForCluster:cluster];
  if (!clusterManagerId) {
    return;
  }
  FGMPlatformCluster *platFormCluster = FGMGetPigeonCluster(cluster, clusterManagerId);
  [self.eventDelegate didTapCluster:platFormCluster];
}

#pragma mark - Private methods

/// Returns the integral zoom level used for clustering.
- (NSUInteger)integralZoom {
  // Ref:
  // https://github.com/googlemaps/google-maps-ios-utils/blob/0e7ed81f1bbd9d29e4529c40ae39b0791b0a0eb8/src/Clustering/GMUClusterManager.m#L94.
  return (NSUInteger)floorf(self.mapView.camera.zoom + 0.5f);
}

/// Sends the current clusters of the cluster manager with the given identifier to the event
/// delegate.
- (void)sendClustersWithIdentifier:(NSString *)identifier {
  FlutterError *error;
  NSArray<FGMPlatformCluster *> *clusters = [self clustersWithIdentifier:identifier error:&error];
  if (!clusters) {
    return;
  }
  self.clusterManagerIdentifierToLastUpdateZoom[identifier] = @([self integralZoom]);
  [self.eventDelegate didUpdateClustersWithIdentifier:identifier clusters:clusters];
}

/// Returns the cluster manager identifier for given cluster.
///
/// @return The cluster manager identifier if found; otherwise, nil.
- (nullable NSString *)clusterManagerIdentifierForCluster:(GMUStaticCluster *)cluster {
  if ([cluster.items.firstObject isKindOfClass:[GMSMarker class]]) {
    GMSMarker *firstMarker = (GMSMarker *)cluster.items.firstObject;
    return FGMGetClusterManagerIdentifierFromMarker(firstMarker);
  }

  return nil;
}

@end
