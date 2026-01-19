import RealityKit

class RealityKitViewController: UIViewController {
    @IBOutlet var arView: ModelARView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (arView == nil) {
            arView = ModelARView(frame: view.frame)
        }
        view.addSubview(arView)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // pause session on view disappear
        arView.pause()
        arView.session.delegate = nil
        arView.scene.anchors.removeAll()
        arView.removeFromSuperview()
        arView = nil
    }
    
    func setUp() {
        arView.setUp()
    }
    
    func loadEntity(src: String) -> Entity? {
        print("src ------ \(src)")
        // load the model
        guard let url = URL(string: src) else {
            print("Invalid model URL:", src)
            return nil
        }

        print("Model URL:", url)
        
        if let modelEntity = try? ModelEntity.load(contentsOf: url) {
            print("Model loaded")
            return modelEntity;
        }
        
        // Create a new alert
        let dialogMessage = UIAlertController(title: "Error", message: "Cannot load the requested model file.", preferredStyle: .alert)
        dialogMessage.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in }))
        // Present alert to user
        self.present(dialogMessage, animated: true, completion: nil)
        return nil
    }
    
    func changePlaneOrientation(planeOrientation: String) {
        arView.changePlaneDetection(planeDetection: planeOrientation)
    }
    
    func changeInstructionVisibility(isVisible: Bool) {
        arView.setInstructionsVisibility(isVisible: isVisible)
    }
    
    func changeModel(model: String) {
        guard let entity = loadEntity(src: model) else { return }
        // Scale the arrow MUCH smaller
        entity.scale = SIMD3<Float>(repeating: 0.001)

        // Rotate arrow so it points DOWN instead of RIGHT
        // Rotate -90° around X axis → arrow points down
        entity.transform.rotation = simd_quatf(angle: -.pi/2, axis: [0, 0, 1])
      
        entity.position.y += 0.04
        arView.changeEntity(modelEntity: entity)
    }
    
    func placeModel(position: simd_float3, model: Entity) {
        let anchor = AnchorEntity(world: position)

        let modelClone = model.clone(recursive: true)
        anchor.addChild(modelClone)

        arView.scene.addAnchor(anchor)
        arView.appendModelAnchor(modelAnchor: anchor)
    }
    
    func changeLightEstimationEnabled(isEnabled: Bool) {
        arView.setLightEstimationEnabled(isEnabled: isEnabled)
    }
    
    func changeDepthManagementEnabled(isEnabled: Bool) {
        arView.setDepthManagement(isEnabled: isEnabled)
    }
    
    
    public func worldPointFromScreen(x: Float, y: Float) -> simd_float3? {
        let screenPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
        
      
        if let result = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any).first {
            let transform = result.worldTransform
            let worldTranslation = simd_float3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            return worldTranslation
          
        }
      
        print("unable to cast ray!!!!!!")
        
        return nil
    }
    
    func hexToUIColor(hex: String) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        
        guard hexSanitized.count == 6 else { return nil }
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        return UIColor(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
    
    public func createLineAndGetDistance(position1: simd_float3, position2: simd_float3, color: String,requestId: Int){
        var colorToBeUsed: UIColor = .white
        
        if let newColor = hexToUIColor(hex: color){
            colorToBeUsed = newColor
        } else {
            colorToBeUsed = .white
        }
        
        let line = Line(arView: arView, startPosition: position1, unit: .centimeter, color: colorToBeUsed)
        line.update(to: position2)
        
        arView.onDataReturnedHandler([
            "requestId":requestId,
            "result":line.distanceText,
            "error": ""
        ])
        
    }
    
    private func createTextEntity(text: String, color: UIColor) -> ModelEntity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.01),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        material.metallic = .float(0.0)
        material.roughness = .float(1.0)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        entity.position = .zero
        if #available(iOS 18.0, *) {
            entity.components[BillboardComponent.self] = BillboardComponent()
        } else {
            // Fallback on earlier versions
        }
        
        return entity
    }
    
    public func placeText(text: String,position: simd_float3, color: String,){
        var colorToBeUsed: UIColor = .white
        
        if let newColor = hexToUIColor(hex: color){
            colorToBeUsed = newColor
        } else {
            colorToBeUsed = .white
        }
        
        var anchorEntity = AnchorEntity(world: position)
        arView.scene.addAnchor(anchorEntity)
        
        var textEntity = createTextEntity(text: text, color: colorToBeUsed)
        anchorEntity.addChild(textEntity)
        
    }
    
    func changeInstantPlacementEnabled(isEnabled: Bool) {
        arView.setInstantPlacementEnabled(isEnabled: isEnabled)
    }
    
    func changeAllowRotate(isAllowed: Bool) {
        arView.setAllowRotate(isEnabled: isAllowed)
    }
    
    func changeAllowTranslate(isAllowed: Bool) {
        arView.setAllowTranslate(isEnabled: isAllowed)
    }
    
    func changeAllowScale(isAllowed: Bool) {
        arView.setAllowScale(isEnabled: isAllowed)
    }
    
    func run() {
        arView.readyToStart = true
        arView.start()
    }
    
    /// Set on started event
    func setOnStartedHandler(handler: @escaping RCTDirectEventBlock) {
        arView.setOnStartedHandler(handler: handler)
    }
    
    /// Set on error event
    func setOnErrorHandler(handler: @escaping RCTDirectEventBlock) {
        arView.setOnErrorHandler(handler: handler)
    }
    
    func setOnUserTapHandler(handler: @escaping RCTDirectEventBlock) {
        arView.setOnUserTapHandler(handler: handler)
    }
    
    /// Set on data returned handler (used to resolve promises on JS side)
    func setOnDataReturnedHandler(handler: @escaping RCTDirectEventBlock) {
        arView.setOnDataReturnedHandler(handler: handler)
    }
    
    /// Set on data returned handler (used to resolve promises on JS side)
    func setOnEndedHandler(handler: @escaping RCTDirectEventBlock) {
        arView.setOnEndedHandler(handler: handler)
    }
    
    /// Set on data returned handler (used to resolve promises on JS side)
    func setOnModelPlacedHandler(handler: @escaping RCTDirectEventBlock) {
        arView.setOnModelPlacedHandler(handler: handler)
    }
    
    /// Set on data returned handler (used to resolve promises on JS side)
    func setOnModelRemovedHandler(handler: @escaping RCTDirectEventBlock) {
        arView.setOnModelRemovedHandler(handler: handler)
    }
}