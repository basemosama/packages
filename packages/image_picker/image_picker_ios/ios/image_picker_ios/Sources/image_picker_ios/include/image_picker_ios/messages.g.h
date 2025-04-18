// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// Autogenerated from Pigeon (v22.4.1), do not edit directly.
// See also: https://pub.dev/packages/pigeon

#import <Foundation/Foundation.h>

@protocol FlutterBinaryMessenger;
@protocol FlutterMessageCodec;
@class FlutterError;
@class FlutterStandardTypedData;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FLTSourceCamera) {
  FLTSourceCameraRear = 0,
  FLTSourceCameraFront = 1,
};

/// Wrapper for FLTSourceCamera to allow for nullability.
@interface FLTSourceCameraBox : NSObject
@property(nonatomic, assign) FLTSourceCamera value;
- (instancetype)initWithValue:(FLTSourceCamera)value;
@end

typedef NS_ENUM(NSUInteger, FLTSourceType) {
  FLTSourceTypeCamera = 0,
  FLTSourceTypeGallery = 1,
};

/// Wrapper for FLTSourceType to allow for nullability.
@interface FLTSourceTypeBox : NSObject
@property(nonatomic, assign) FLTSourceType value;
- (instancetype)initWithValue:(FLTSourceType)value;
@end

@class FLTMaxSize;
@class FLTMediaSelectionOptions;
@class FLTSourceSpecification;

@interface FLTMaxSize : NSObject
+ (instancetype)makeWithWidth:(nullable NSNumber *)width height:(nullable NSNumber *)height;
@property(nonatomic, strong, nullable) NSNumber *width;
@property(nonatomic, strong, nullable) NSNumber *height;
@end

@interface FLTMediaSelectionOptions : NSObject
/// `init` unavailable to enforce nonnull fields, see the `make` class method.
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)makeWithMaxSize:(FLTMaxSize *)maxSize
                   imageQuality:(nullable NSNumber *)imageQuality
            requestFullMetadata:(BOOL)requestFullMetadata
                  allowMultiple:(BOOL)allowMultiple
                          limit:(nullable NSNumber *)limit;
@property(nonatomic, strong) FLTMaxSize *maxSize;
@property(nonatomic, strong, nullable) NSNumber *imageQuality;
@property(nonatomic, assign) BOOL requestFullMetadata;
@property(nonatomic, assign) BOOL allowMultiple;
@property(nonatomic, strong, nullable) NSNumber *limit;
@end

@interface FLTSourceSpecification : NSObject
/// `init` unavailable to enforce nonnull fields, see the `make` class method.
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)makeWithType:(FLTSourceType)type camera:(FLTSourceCamera)camera;
@property(nonatomic, assign) FLTSourceType type;
@property(nonatomic, assign) FLTSourceCamera camera;
@end

/// The codec used by all APIs.
NSObject<FlutterMessageCodec> *FLTGetMessagesCodec(void);

@protocol FLTImagePickerApi
- (void)pickImageWithSource:(FLTSourceSpecification *)source
                    maxSize:(FLTMaxSize *)maxSize
                    quality:(nullable NSNumber *)imageQuality
               fullMetadata:(BOOL)requestFullMetadata
                 completion:(void (^)(NSString *_Nullable, FlutterError *_Nullable))completion;
- (void)pickMultiImageWithMaxSize:(FLTMaxSize *)maxSize
                          quality:(nullable NSNumber *)imageQuality
                     fullMetadata:(BOOL)requestFullMetadata
                            limit:(nullable NSNumber *)limit
                       completion:(void (^)(NSArray<NSString *> *_Nullable,
                                            FlutterError *_Nullable))completion;
- (void)pickVideoWithSource:(FLTSourceSpecification *)source
                maxDuration:(nullable NSNumber *)maxDurationSeconds
                 completion:(void (^)(NSString *_Nullable, FlutterError *_Nullable))completion;
/// Selects images and videos and returns their paths.
- (void)pickMediaWithMediaSelectionOptions:(FLTMediaSelectionOptions *)mediaSelectionOptions
                                completion:(void (^)(NSArray<NSString *> *_Nullable,
                                                     FlutterError *_Nullable))completion;
@end

extern void SetUpFLTImagePickerApi(id<FlutterBinaryMessenger> binaryMessenger,
                                   NSObject<FLTImagePickerApi> *_Nullable api);

extern void SetUpFLTImagePickerApiWithSuffix(id<FlutterBinaryMessenger> binaryMessenger,
                                             NSObject<FLTImagePickerApi> *_Nullable api,
                                             NSString *messageChannelSuffix);

NS_ASSUME_NONNULL_END
