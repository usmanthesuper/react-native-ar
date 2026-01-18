import ARKit
import RealityKit
import SwiftUI

@available(iOS 13.0, *)
@objc(ArViewerViewManager)
class ArViewerViewManager: RCTViewManager {
    @objc override static func requiresMainQueueSetup() -> Bool {
        return false
    }
        
    override func view() -> UIView {
        return ArViewerView()
    }
    
    @objc func reset(_ node : NSNumber){
        RCTExecuteOnMainQueue {
            if let view = self.bridge.uiManager.view(forReactTag: node) as? ArViewerView {
                view.reset()
            }
        }
    }
    
    @objc func loadModel(_ node : NSNumber){
        RCTExecuteOnMainQueue {
            if let view = self.bridge.uiManager.view(forReactTag: node) as? ArViewerView {
                view.loadModel()
            }
        }
    }
    
    @objc func takeScreenshot(_ node : NSNumber, withRequestId requestId: NSNumber){
        RCTExecuteOnMainQueue {
            if let view = self.bridge.uiManager.view(forReactTag: node) as? ArViewerView {
                view.takeScreenshot(requestId: requestId.intValue)
            }
        }
    }
    
    @objc func getPositionVector3(_ node : NSNumber,withXCoord x: NSNumber, withYCoord y: NSNumber, withRequestId requestId: NSNumber){
        RCTExecuteOnMainQueue {
            if let view = self.bridge.uiManager.view(forReactTag: node) as? ArViewerView {
                view.getPositionVector3(x: x.doubleValue,y: y.doubleValue, requestId: requestId.intValue)
            }
        }
    }
    
    @objc func createLineAndGetDistance(_ node : NSNumber,withX1Coord x1: NSNumber, withY1Coord y1: NSNumber, withZ1Coord z1: NSNumber,withX2Coord x2: NSNumber, withY2Coord y2: NSNumber, withZ2Coord z2: NSNumber,withColor color:NSString, withRequestId requestId: NSNumber){
        RCTExecuteOnMainQueue {
            if let view = self.bridge.uiManager.view(forReactTag: node) as? ArViewerView {
                view.createLineAndGetDistance(x1: x1.doubleValue,y1: y1.doubleValue,z1: z1.doubleValue,x2: x2.doubleValue,y2: y2.doubleValue,z2: z2.doubleValue,color: color as String, requestId: requestId.intValue)
            }
        }
    }
    
    @objc func placeText(_ node : NSNumber,withXCoord x: NSNumber, withYCoord y: NSNumber, withZCoord z: NSNumber,withColor color:NSString, withText text: NSString){
        RCTExecuteOnMainQueue {
            if let view = self.bridge.uiManager.view(forReactTag: node) as? ArViewerView {
                view.placeText(x: x.doubleValue,y: y.doubleValue, z: z.doubleValue,color: color as String,text: text as String)
            }
        }
    }
    
    @objc func placeModel(_ node : NSNumber,withXCoord x: NSNumber, withYCoord y: NSNumber, withZCoord z: NSNumber){
        RCTExecuteOnMainQueue {
            if let view = self.bridge.uiManager.view(forReactTag: node) as? ArViewerView {
                view.placeModel(x: x.doubleValue,y: y.doubleValue, z: z.doubleValue)
            }
        }
    }
    
    @objc func rotateModel(_ node : NSNumber, withPitch pitch: NSNumber, withYaw yaw: NSNumber, withRoll roll: NSNumber){
        RCTExecuteOnMainQueue {
            if let view = self.bridge.uiManager.view(forReactTag: node) as? ArViewerView {
                view.rotateModel(pitch: pitch.intValue, yaw: yaw.intValue, roll: roll.intValue)
            }
        }
    }
}


extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}
