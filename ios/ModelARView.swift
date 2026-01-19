import ARKit
import RealityKit

@available(iOS 13.0, *)
class ModelARView: ARView, ARSessionDelegate {
    var modelEntity: Entity!
    var config: ARWorldTrackingConfiguration!
    var grids = [Grid]()
    var isModelVisible: Bool = false {
        didSet {
            if (isModelVisible && self.onModelPlacedHandler != nil) {
                self.onModelPlacedHandler([:])
            } else if(!isModelVisible && self.onModelRemovedHandler != nil) {
                self.onModelRemovedHandler([:])
            }
        }
    }
    var coachingOverlay: ARCoachingOverlayView!
    var isInstantPlacementEnabled: Bool = true
    var allowedGestures: ARView.EntityGestures = []
    var installedGestureRecognizers: [EntityGestureRecognizer] = []
    var isSetup: Bool = false
    var readyToStart: Bool = false
    var sessionStarted: Bool = false
    
    var onStartedHandler: RCTDirectEventBlock!
    var onErrorHandler: RCTDirectEventBlock!
    var onUserTapHandler: RCTDirectEventBlock!
    var onDataReturnedHandler: RCTDirectEventBlock!
    var onEndedHandler: RCTDirectEventBlock!
    var onModelPlacedHandler: RCTDirectEventBlock!
    var onModelRemovedHandler: RCTDirectEventBlock!
    
    var modelAnchors: [AnchorEntity] = []
    
    required init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required dynamic init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    /// Setup the view
    func setUp() {
        // manage orientation change
        self.autoresizingMask = [
            .flexibleWidth, .flexibleHeight
        ]
        
        renderOptions.insert(.disableAREnvironmentLighting)
        // Add coaching overlay
        coachingOverlay = ARCoachingOverlayView(frame: frame)
        // setup the instructions
        coachingOverlay.goal = .anyPlane
        coachingOverlay.session = self.session
        // Make sure it rescales if the device orientation changes
        coachingOverlay.autoresizingMask = [
            .flexibleWidth, .flexibleHeight
        ]
        // update frame
        coachingOverlay.frame = self.frame
        self.addSubview(coachingOverlay)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.isLightEstimationEnabled = false
        if #available(iOS 13.4, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                config.sceneReconstruction = .mesh
            }
        }
        
        // load environment lighting from HDR file
        let frameworkBundle = Bundle(for: ArViewerViewManager.self)
        let bundleURL = frameworkBundle.resourceURL?.appendingPathComponent("ArViewerBundle.bundle")
        let resourceBundle = Bundle(url: bundleURL!)
        
        do {
            let skyboxResource = try EnvironmentResource.load(named: "ref", in: resourceBundle)
            environment.lighting.resource = skyboxResource
        } catch {
            let message = "Cannot load environment texture, please check installation guide. Models may appear darker than expected."
            print(message)
        }
        
        self.config = config
        
        // manage session here
        self.session.delegate = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        tap.name = "gridTap"
        self.addGestureRecognizer(tap)
        
        isSetup = true
    }
    
    /// Hide all grids and display the model on the provided one
    func showModel(grid: Grid, model: Entity) {
        for gr in grids {
            if (gr != grid) {
                gr.isEnabled = false
            }
        }
        
        grid.isEnabled = true
//        grid.replaceModel(model: modelEntity)
//        isModelVisible = true
//        setGestures()
    }
    
    /// Reset the views and all grids
    func reset() {
        for grid in self.grids {
            grid.reset()
            grid.isEnabled = true
        }
        isModelVisible = false
        setGestures()
        safelyResetArrowAnchors()
        self.scene.anchors.removeAll()
        
    }
    
    /// Start or update the AR session
    func start() {
        if (isSetup && readyToStart) {
            self.session.run(self.config)
            if(!sessionStarted) {
                sessionStarted = true
                if (onStartedHandler != nil) {
                    onStartedHandler([:])
                }
            }
        }
    }
    
    
    /// Pause the AR session
    func pause() {
        self.session.pause()
        sessionStarted = false
        if (onEndedHandler != nil) {
            onEndedHandler([:])
        }
    }
    
    
    /// Set the plane orientation to detect
    func changePlaneDetection(planeDetection: String) {
        switch planeDetection {
            case "none":
                self.coachingOverlay.goal = .tracking
                self.config.planeDetection = []
            case "horizontal":
                self.coachingOverlay.goal = .horizontalPlane
                self.config.planeDetection = .horizontal
            case "vertical":
                self.coachingOverlay.goal = .verticalPlane
                self.config.planeDetection = .vertical
            default:
                // both
                self.coachingOverlay.goal = .anyPlane
                self.config.planeDetection = [.horizontal, .vertical]
        }
        // and update runtime config
        self.start()
    }
    
    
    func takeSnapshot(requestId: Int) {
        guard let currentFrame = self.session.currentFrame else { return }
        
        
    //    savedTransform = currentFrame.camera.transform
        
        // Extract the image from the frame
        let pixelBuffer = currentFrame.capturedImage
        
        let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let viewPort = self.bounds
        let viewPortSize = self.bounds.size
        
        let interfaceOrientation: UIInterfaceOrientation

        if #available(iOS 13.0, *) {
          if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
              interfaceOrientation = windowScene.interfaceOrientation
              print("Current orientation: \(interfaceOrientation.rawValue)")
          } else {
            interfaceOrientation = self.window!.windowScene!.interfaceOrientation
            print("interfaceOrientation \(interfaceOrientation.rawValue)")
          }
        } else {
          interfaceOrientation = UIApplication.shared.statusBarOrientation
        }
        
        let image = CIImage(cvImageBuffer: pixelBuffer)
        
        // Transform the image:
        // 1) Convert to "normalized image coordinates"
        let normalizeTransform = CGAffineTransform(scaleX: 1.0/imageSize.width, y: 1.0/imageSize.height)
        
        // 2) Flip the Y axis (for portrait mode)
        let flipTransform = (interfaceOrientation.isPortrait) ?
        CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -1, y: -1) : .identity
        
        // 3) Apply the ARFrame display transform
        let displayTransform = currentFrame.displayTransform(for: interfaceOrientation, viewportSize: viewPortSize)
        
        // 4) Convert to view size
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width, y: viewPortSize.height)
        
        // Transform the image and crop it to the viewport
        let transformedImage = image
          .transformed(by: normalizeTransform
            .concatenating(flipTransform)
            .concatenating(displayTransform)
            .concatenating(toViewPortTransform))
          .cropped(to: viewPort)
        
        let context = CIContext()

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            self.onErrorHandler?(["message": "Failed to save snapshot"])
            return
        }
        
        let fileName = "snapshot_\(requestId)_\(Date().timeIntervalSince1970).jpg"
        
        // Get the temporary directory (or documents directory)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let uiImage = UIImage(cgImage: cgImage)

        guard let data = uiImage.pngData() else {
            self.onErrorHandler?(["message": "Failed to save snapshot"])
            return
        }

        
        
        do {
            try data.write(to: fileURL)
            print("Saved at:", fileURL)
            
            let fileURI = fileURL.absoluteString
            
            // Return the URI to React Native
            if let handler = self.onDataReturnedHandler {
                handler([
                    "requestId": requestId,
                    "result": fileURI,  // file:///.../snapshot_123_1234567890.jpg
                    "error": ""
                ])
            }
        } catch {
            self.onErrorHandler?(["message": "Failed to save snapshot: \(error.localizedDescription)"])
        }
    }
    
    func getPositionVector3(x: Double,y: Double,z: Double,requestId: Int) {
        
        
        if (self.onDataReturnedHandler != nil) {
            print("sending data back to RN")
            self.onDataReturnedHandler([
                "requestId": requestId,
                "result": [
                    "x": x,
                    "y": y,
                    "z": z
                ],
                "error": ""
            ])
        }
    }
    
    /// Change the model to render
    func changeEntity(modelEntity: Entity) {
//        if (isModelVisible) {
//            for grid in self.grids {
//                if (grid.isShowingModel) {
//                    grid.replaceModel(model: modelEntity)
//                }
//            }
//        }
        self.modelEntity = modelEntity
//        tryInstantPlacement()
    }
    
    func appendModelAnchor(modelAnchor: AnchorEntity){
        modelAnchors.append(modelAnchor)
    }
    
    func resetModelAnchors() {
        modelAnchors.forEach { anchor in
            anchor.removeFromParent()
        }
        modelAnchors.removeAll()
    }
    
    func safelyResetArrowAnchors() {
        DispatchQueue.main.async {
            self.resetModelAnchors()
        }
    }
    
    /// Enable/Disable coaching view
    func setInstructionsVisibility(isVisible: Bool) {
        guard (self.subviews.firstIndex(of: coachingOverlay) != nil) else {
            // no coaching view present
            if (isVisible) {
                coachingOverlay.activatesAutomatically = true
                coachingOverlay.setActive(true, animated: true)
            }
            return
        }
        
        // coaching is present
        if (!isVisible) {
            coachingOverlay.activatesAutomatically = false
            coachingOverlay.setActive(false, animated: true)
        }
    }
    
    /// Enable/Disable environment occlusion
    func setDepthManagement(isEnabled: Bool) {
        if #available(iOS 13.4, *) {
            if(isEnabled) {
                environment.sceneUnderstanding.options.insert(.occlusion)
            } else {
                environment.sceneUnderstanding.options.remove(.occlusion)
            }
        }
    }
    
    /// Enable/Disable light estimation
    func setLightEstimationEnabled(isEnabled: Bool) {
        config.isLightEstimationEnabled = isEnabled
        start()
    }
    
    
    /// Enable/Disable instant placement mode
    func setInstantPlacementEnabled(isEnabled: Bool) {
        self.isInstantPlacementEnabled = isEnabled
//        tryInstantPlacement()
    }
    
    
    /// Try to automatically add the model on the first anchor found
    func tryInstantPlacement() {
        if (isInstantPlacementEnabled && !isModelVisible && grids.count > 0 && self.modelEntity != nil) {
            // place it on first anchor
            guard let grid: Grid = grids.first else {
                return
            }
            self.showModel(grid: grid, model: self.modelEntity)
        }
    }
    
    /// Register all gesture handlers
    func setGestures() {
        // reset all gestures
        for gestureRecognizer in gestureRecognizers! {
            guard let index = gestureRecognizers?.firstIndex(of: gestureRecognizer) else {
                return
            }
            if (gestureRecognizer.name != "gridTap") {
                gestureRecognizers?.remove(at: index)
            }
        }
        // install new gestures
        for grid in grids {
            if (grid.isShowingModel) {
                installGestures(.init(arrayLiteral: self.allowedGestures), for: grid)
            }
        }
    }
    
    /// Enable/Disabled user gesture on model: rotation
    func setAllowRotate(isEnabled: Bool) {
        if (isEnabled) {
            self.allowedGestures.insert(.rotation)
        } else {
            self.allowedGestures.remove(.rotation)
        }
        setGestures()
    }
    
    /// Enable/Disable user gesture on model: scale
    func setAllowScale(isEnabled: Bool) {
        if (isEnabled) {
            self.allowedGestures.insert(.scale)
        } else {
            self.allowedGestures.remove(.scale)
        }
        setGestures()
    }
    
    
    /// Enable/Disable user gesture on model: translation
    func setAllowTranslate(isEnabled: Bool) {
        if (isEnabled) {
            self.allowedGestures.insert(.translation)
        } else {
            self.allowedGestures.remove(.translation)
        }
        setGestures()
    }
    
    
    /// Converts degrees to radians
    func deg2rad(_ number: Int) -> Float {
        return Float(number) * .pi / 180
    }
    
    /// Rotate the model
    func rotateModel(pitch: Int, yaw: Int, roll: Int) -> Void {
        guard isModelVisible else { return }
        for plane in self.grids {
            if (plane.isShowingModel) {
                let transform = Transform(pitch: deg2rad(pitch), yaw: deg2rad(yaw), roll: deg2rad(roll))
                let currentMatrix = plane.transform.matrix
                let calculated = simd_mul(currentMatrix, transform.matrix)
                plane.move(to: calculated, relativeTo: nil, duration: 1)
            }
        }
    }
    
    // Set our events handlers
    /// Set on started event
    func setOnStartedHandler(handler: @escaping RCTDirectEventBlock) {
        onStartedHandler = handler
    }
    
    /// Set on error event
    func setOnErrorHandler(handler: @escaping RCTDirectEventBlock) {
        onErrorHandler = handler
    }
    
    func setOnUserTapHandler(handler: @escaping RCTDirectEventBlock) {
        onUserTapHandler = handler
    }
    
    /// Set on data returned handler (used to resolve promises on JS side)
    func setOnDataReturnedHandler(handler: @escaping RCTDirectEventBlock) {
        onDataReturnedHandler = handler
    }
    
    /// Set on ended event
    func setOnEndedHandler(handler: @escaping RCTDirectEventBlock) {
        onEndedHandler = handler
    }
    
    /// Set on model placed handler
    func setOnModelPlacedHandler(handler: @escaping RCTDirectEventBlock) {
        onModelPlacedHandler = handler
    }
    
    /// Set on model removed handler
    func setOnModelRemovedHandler(handler: @escaping RCTDirectEventBlock) {
        onModelRemovedHandler = handler
    }
    
    /// Sending x and y cords to rn side
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {

        guard let handler = self.onUserTapHandler,
              let sender = sender else { return }
        
        
        let point = sender.location(in: self)
        
        handler([
            "coordinates": [
                "x": point.x,
                "y": point.y
            ]
        ])
    }
}
