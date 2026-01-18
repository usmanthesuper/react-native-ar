#import "React/RCTViewManager.h"

@interface RCT_EXTERN_MODULE(ArViewerViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(model, NSString)
RCT_EXPORT_VIEW_PROPERTY(planeOrientation, NSString)
RCT_EXPORT_VIEW_PROPERTY(allowScale, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowRotate, BOOL)
RCT_EXPORT_VIEW_PROPERTY(allowTranslate, BOOL)
RCT_EXPORT_VIEW_PROPERTY(lightEstimation, BOOL)
RCT_EXPORT_VIEW_PROPERTY(manageDepth, BOOL)
RCT_EXPORT_VIEW_PROPERTY(disableInstructions, BOOL)
RCT_EXPORT_VIEW_PROPERTY(disableInstantPlacement, BOOL)

RCT_EXTERN_METHOD(reset:(nonnull NSNumber*) reactTag)
RCT_EXTERN_METHOD(loadModel:(nonnull NSNumber*) reactTag)
RCT_EXTERN_METHOD(takeScreenshot:(nonnull NSNumber*)reactTag withRequestId:(nonnull NSNumber*)requestId)
RCT_EXTERN_METHOD(getPositionVector3:(nonnull NSNumber*)reactTag withXCoord:(nonnull NSNumber*)x withYCoord:(nonnull NSNumber*)y withRequestId:(nonnull NSNumber*)requestId)
RCT_EXTERN_METHOD(createLineAndGetDistance:(nonnull NSNumber*)reactTag withX1Coord:(nonnull NSNumber*)x1 withY1Coord:(nonnull NSNumber*)y1 withZ1Coord:(nonnull NSNumber*)z1 withX2Coord:(nonnull NSNumber*)x2 withY2Coord:(nonnull NSNumber*)y2 withZ2Coord:(nonnull NSNumber*)z2 withColor:(nonnull NSString*)color withRequestId:(nonnull NSNumber*)requestId)
RCT_EXTERN_METHOD(placeModel:(nonnull NSNumber*)reactTag withXCoord:(nonnull NSNumber*)x withYCoord:(nonnull NSNumber*)y withZCoord:(nonnull NSNumber*)z)
RCT_EXTERN_METHOD(placeText:(nonnull NSNumber*)reactTag withXCoord:(nonnull NSNumber*)x withYCoord:(nonnull NSNumber*)y withZCoord:(nonnull NSNumber*)z withColor:(nonnull NSString*)color withText:(nonnull NSString*)text)
RCT_EXTERN_METHOD(rotateModel:(nonnull NSNumber*)reactTag withPitch:(nonnull NSNumber*)pitch withYaw:(nonnull NSNumber*)yaw withRoll:(nonnull NSNumber*)roll)

RCT_EXPORT_VIEW_PROPERTY(onStarted, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onUserTap, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDataReturned, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onEnded, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onModelPlaced, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onModelRemoved, RCTDirectEventBlock)

@end

