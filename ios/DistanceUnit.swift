import RealityKit
import ARKit

enum DistanceUnit {
    case centimeter
    case inch
    case meter
    
    var factor: Float {
        switch self {
        case .centimeter:
            return 100.0
        case .inch:
            return 39.3700787
        case .meter:
            return 1.0
        }
    }
    
    var unit: String {
        switch self {
        case .centimeter:
            return "cm"
        case .inch:
            return "inch"
        case .meter:
            return "m"
        }
    }
    
    var title: String {
        switch self {
        case .centimeter:
            return "Centimeter"
        case .inch:
            return "Inch"
        case .meter:
            return "Meter"
        }
    }
}

final class Line {
    private var color: UIColor = .white
    
    private var startEntity: ModelEntity!
    private var endEntity: ModelEntity!
    private var lineEntity: ModelEntity?
    private var textEntity: ModelEntity!
    
    private let arView: ARView!
    private let startPosition: SIMD3<Float>!
    private let unit: DistanceUnit!
    private let anchorEntity: AnchorEntity
    
    public var distanceText: String!
    
    init(arView: ARView, startPosition: SIMD3<Float>, unit: DistanceUnit, color: UIColor) {
        self.arView = arView
        self.startPosition = startPosition
        self.unit = unit
        self.color = color
        
        // Create anchor entity
        self.anchorEntity = AnchorEntity(world: startPosition)
        arView.scene.addAnchor(anchorEntity)
        
        // Create start dot
        let dotMesh = MeshResource.generateSphere(radius: 0.001)
        var dotMaterial = SimpleMaterial()
        dotMaterial.color = .init(tint: color)
        dotMaterial.metallic = .float(0.0)
        dotMaterial.roughness = .float(1.0)
        
        startEntity = ModelEntity(mesh: dotMesh, materials: [dotMaterial])
        startEntity.position = [0, 0, 0] // Relative to anchor
        anchorEntity.addChild(startEntity)
        
        // Create end dot
        endEntity = ModelEntity(mesh: dotMesh, materials: [dotMaterial])
        
        // Create text entity
        textEntity = createTextEntity(text: "")
        anchorEntity.addChild(textEntity)
    }
    
    private func createTextEntity(text: String) -> ModelEntity {
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
    
    func update(to position: SIMD3<Float>) {
        // Remove old line
        lineEntity?.removeFromParent()
        
        // Create new line
        let startWorld = startPosition!
        let endWorld = position
        
        lineEntity = createLine(from: startWorld, to: endWorld)
        if let lineEntity = lineEntity {
            anchorEntity.addChild(lineEntity)
        }
        
        // Update text
        distanceText = distance(to: position)
        textEntity.removeFromParent()
        textEntity = createTextEntity(text: distanceText)
        
        // Position text at midpoint
        let midpoint = (startWorld + endWorld) / 2.0
        let relativePosition = midpoint - startPosition
        textEntity.position = relativePosition
        
        anchorEntity.addChild(textEntity)
        
        // Update end dot position
        endEntity.position = position - startPosition
        if endEntity.parent == nil {
            anchorEntity.addChild(endEntity)
        }
    }
    
    private func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>) -> ModelEntity {
        let vector = end - start
        let distance = length(vector)
        
        // Create cylinder as line
        let mesh = MeshResource.generateBox(width: 0.0005, height: distance, depth: 0.0005)
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        material.metallic = .float(0.0)
        material.roughness = .float(1.0)
        
        let lineEntity = ModelEntity(mesh: mesh, materials: [material])
        
        // Position at midpoint
        let midpoint = (start + end) / 2.0
        lineEntity.position = midpoint - startPosition
        
        // Rotate to align with vector
        let up = SIMD3<Float>(0, 1, 0)
        let direction = normalize(vector)
        
        if abs(dot(direction, up)) < 0.999 {
            let axis = cross(up, direction)
            let angle = acos(dot(up, direction))
            lineEntity.orientation = simd_quatf(angle: angle, axis: normalize(axis))
        } else if dot(direction, up) < 0 {
            lineEntity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        }
        
        return lineEntity
    }
    
    func distance(to position: SIMD3<Float>) -> String {
        let dist = length(position - startPosition)
        return String(format: "%.2f%@", dist * unit.factor, unit.unit)
    }
    
    func removeFromParent() {
        anchorEntity.removeFromParent()
    }
}

// SIMD3 extension for distance calculation
extension SIMD3 where Scalar == Float {
    func distance(from other: SIMD3<Float>) -> Float {
        return length(self - other)
    }
}
