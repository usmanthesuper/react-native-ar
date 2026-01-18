import SwiftUI

class ArViewerView: UIView {

    var arViewController: RealityKitViewController!

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        if arViewController == nil {
            // setup subview
            guard let parentViewController = parentViewController else { return }

            arViewController = RealityKitViewController()
            arViewController.view.frame = bounds
            parentViewController.addChild(arViewController)
            addSubview(arViewController.view)
            arViewController.didMove(toParent: parentViewController)
            
            arViewController.setUp()
            // re-run all setters now that the view is mounted
            arViewController.changePlaneOrientation(planeOrientation: planeOrientation)
            arViewController.changeInstructionVisibility(isVisible: !disableInstructions)
            arViewController.changeLightEstimationEnabled(isEnabled: lightEstimation)
            arViewController.changeDepthManagementEnabled(isEnabled: manageDepth)
            arViewController.changeInstantPlacementEnabled(isEnabled: !disableInstantPlacement)
            arViewController.changeAllowScale(isAllowed: allowScale)
            arViewController.changeAllowRotate(isAllowed: allowRotate)
            arViewController.changeAllowTranslate(isAllowed: allowTranslate)
//            arViewController.changeModel(model: model)
            // set events
            if (onError != nil) {
                arViewController.setOnErrorHandler(handler: onError!)
            }
            if(onUserTap != nil){
                arViewController.setOnUserTapHandler(handler: onUserTap!)
            }
            if (onStarted != nil) {
                arViewController.setOnStartedHandler(handler: onStarted!)
            }
            if (onDataReturned != nil) {
                arViewController.setOnDataReturnedHandler(handler: onDataReturned!)
            }
            if (onEnded != nil) {
                arViewController.setOnEndedHandler(handler: onEnded!)
            }
            if (onModelPlaced != nil) {
                arViewController.setOnModelPlacedHandler(handler: onModelPlaced!)
            }
            if (onModelRemoved != nil) {
                arViewController.setOnModelRemovedHandler(handler: onModelRemoved!)
            }
            // and start session
            arViewController.run()
        } else {
            // update frame
            arViewController?.view.frame = bounds
        }
    }
    
    // reset the view
    @objc func reset() -> Void {
        arViewController?.arView.reset()
    }
    
    @objc func placeModel(x: Double, y: Double, z: Double) -> Void {
        if let model = arViewController?.arView.modelEntity {
            
            let position = SIMD3<Float>(
                x: Float(x),
                y: Float(y),
                z: Float(z)
            )

            arViewController?.placeModel(
                position: position,
                model: model
            )
        }
        
        
    }
    
    @objc func placeText(x: Double, y: Double, z: Double, color: String, text: String) -> Void {
        let position = SIMD3<Float>(
            x: Float(x),
            y: Float(y),
            z: Float(z)
        )
        
        arViewController.placeText(text: text, position: position, color: color)
        
        
    }
    
    @objc func loadModel() -> Void {
//        arViewController?.arView.loadModel()
        arViewController.changeModel(model: model)
    }
    
    // take a snapshot
    @objc func takeScreenshot(requestId: Int) -> Void {
        arViewController?.arView.takeSnapshot(requestId: requestId)
    }
    
    // get position vector 3 from x and y cords
    @objc func getPositionVector3(x: Double,y: Double, requestId: Int) -> Void {
        if let worldPosition = arViewController.worldPointFromScreen(x: Float(x), y: Float(y)) {
            print("World position: x=\(worldPosition.x), y=\(worldPosition.y), z=\(worldPosition.z)")
            arViewController?.arView.getPositionVector3(x:Double(worldPosition.x), y: Double(worldPosition.y),z: Double(worldPosition.z),requestId: requestId)
            
        } else {
            print("No surface detected at that screen point")
        }
    }
    
    @objc func createLineAndGetDistance(x1: Double,y1: Double,z1: Double,x2: Double,y2: Double,z2: Double,color: String, requestId: Int) -> Void {
        let position1 = SIMD3<Float>(
            x: Float(x1),
            y: Float(y1),
            z: Float(z1)
        )
        let position2 = SIMD3<Float>(
            x: Float(x2),
            y: Float(y2),
            z: Float(z2)
        )
        arViewController.createLineAndGetDistance(position1: position1,position2: position2,color:color,requestId:requestId)
    }
    
    // rotate model
    @objc func rotateModel(pitch: Int, yaw: Int, roll: Int) -> Void {
        arViewController?.arView.rotateModel(pitch: pitch, yaw: yaw, roll: roll)
    }
    
    /// Remind that properties can be set before the view has been initialized
    @objc var model: String = ""
    
    @objc var planeOrientation: String = "" {
      didSet {
          arViewController?.changePlaneOrientation(planeOrientation: planeOrientation)
      }
    }
    
    @objc var disableInstructions: Bool = false {
      didSet {
          arViewController?.changeInstructionVisibility(isVisible: !disableInstructions)
      }
    }
    
    @objc var lightEstimation: Bool = false {
      didSet {
          arViewController?.changeLightEstimationEnabled(isEnabled: lightEstimation)
      }
    }
    
    @objc var manageDepth: Bool = false {
      didSet {
          arViewController?.changeDepthManagementEnabled(isEnabled: manageDepth)
      }
    }
    
    @objc var disableInstantPlacement: Bool = false {
      didSet {
          arViewController?.changeInstantPlacementEnabled(isEnabled: !disableInstantPlacement)
      }
    }
    
    @objc var allowRotate: Bool = false {
      didSet {
          arViewController?.changeAllowRotate(isAllowed: allowRotate)
      }
    }
    
    @objc var allowScale: Bool = false {
      didSet {
          arViewController?.changeAllowScale(isAllowed: allowScale)
      }
    }
    
    @objc var allowTranslate: Bool = false {
      didSet {
          arViewController?.changeAllowTranslate(isAllowed: allowTranslate)
      }
    }
    
    @objc var onStarted: RCTDirectEventBlock? {
        didSet {
            arViewController?.setOnStartedHandler(handler: onStarted!)
        }
    }
    
    @objc var onDataReturned: RCTDirectEventBlock? {
        didSet {
            arViewController?.setOnDataReturnedHandler(handler: onDataReturned!)
        }
    }
    
    @objc var onError: RCTDirectEventBlock? {
        didSet {
            arViewController?.setOnErrorHandler(handler: onError!)
        }
    }
    
    @objc var onUserTap: RCTDirectEventBlock? {
        didSet {
            arViewController?.setOnUserTapHandler(handler: onUserTap!)
        }
    }
    
    @objc var onEnded: RCTDirectEventBlock? {
        didSet {
            arViewController?.setOnEndedHandler(handler: onError!)
        }
    }
    
    @objc var onModelPlaced: RCTDirectEventBlock? {
        didSet {
            arViewController?.setOnModelPlacedHandler(handler: onError!)
        }
    }
    
    @objc var onModelRemoved: RCTDirectEventBlock? {
        didSet {
            arViewController?.setOnModelRemovedHandler(handler: onError!)
        }
    }
}
