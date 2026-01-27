# React Native AR Viewer - Architecture Diagram

## Project Overview
A React Native library that provides AR (Augmented Reality) capabilities for both iOS and Android platforms, enabling 3D model viewing, placement, manipulation, and measurement in AR space.

---

## High-Level Architecture

```mermaid
graph TB
    subgraph "React Native Layer"
        App[Example App<br/>App.tsx]
        ArView[ArViewerView Component<br/>index.tsx]
    end
    
    subgraph "Bridge Layer"
        UIManager[UIManager Commands]
        Events[Event Handlers]
    end
    
    subgraph "iOS Native Layer"
        ViewManager_iOS[ArViewerViewManager.swift]
        ArViewSwift[ArViewerView.swift]
        ModelAR[ModelARView.swift]
        RealityKit[RealityKitViewController.swift]
        ARKit[ARKit Framework]
    end
    
    subgraph "Android Native Layer"
        ViewManager_Android[ArViewerViewManager.kt]
        ArViewKotlin[ArViewerView.kt]
        SceneView[SceneView Android]
        ARCore[ARCore Framework]
    end
    
    App --> ArView
    ArView --> UIManager
    ArView --> Events
    
    UIManager --> ViewManager_iOS
    UIManager --> ViewManager_Android
    
    Events --> ViewManager_iOS
    Events --> ViewManager_Android
    
    ViewManager_iOS --> ArViewSwift
    ArViewSwift --> ModelAR
    ModelAR --> RealityKit
    RealityKit --> ARKit
    
    ViewManager_Android --> ArViewKotlin
    ArViewKotlin --> SceneView
    SceneView --> ARCore
    
    style App fill:#e1f5ff
    style ArView fill:#b3e5fc
    style ViewManager_iOS fill:#c8e6c9
    style ViewManager_Android fill:#fff9c4
```

---

## Component Structure

### 1. **React Native Layer**

```mermaid
graph LR
    subgraph "ArViewerView Component"
        Props[Props<br/>- model<br/>- planeOrientation<br/>- allowScale/Rotate/Translate<br/>- lightEstimation<br/>- manageDepth]
        State[State<br/>- cameraPermission<br/>- requestMap]
        Methods[Methods<br/>- takeScreenshot<br/>- reset<br/>- loadModel<br/>- rotate<br/>- placeModel<br/>- placeText<br/>- getPositionVector3<br/>- createLineAndGetDistance]
        Events[Event Callbacks<br/>- onStarted<br/>- onEnded<br/>- onModelPlaced<br/>- onModelRemoved<br/>- onUserTap<br/>- onError]
    end
    
    Props --> Methods
    State --> Methods
    Methods --> Events
    
    style Props fill:#ffccbc
    style State fill:#c5cae9
    style Methods fill:#b2dfdb
    style Events fill:#f8bbd0
```

### 2. **Data Flow**

```mermaid
sequenceDiagram
    participant App as Example App
    participant ArView as ArViewerView
    participant Bridge as React Native Bridge
    participant Native as Native Module
    participant AR as AR Framework
    
    App->>ArView: Initialize with props
    ArView->>Bridge: Request camera permission
    Bridge->>Native: Check/Request permission
    Native-->>ArView: Permission granted
    
    App->>ArView: User taps screen
    ArView->>Bridge: getPositionVector3(x, y)
    Bridge->>Native: Dispatch command
    Native->>AR: Hit test at coordinates
    AR-->>Native: Return 3D position
    Native-->>Bridge: Send result event
    Bridge-->>ArView: Resolve promise
    ArView-->>App: Return world position
    
    App->>ArView: placeModel(x, y, z)
    ArView->>Bridge: Dispatch command
    Bridge->>Native: Place model
    Native->>AR: Add model to scene
    AR-->>Native: Model placed
    Native-->>Bridge: onModelPlaced event
    Bridge-->>ArView: Trigger callback
    ArView-->>App: onModelPlaced()
```

---

## Feature Breakdown

### **Core Features**

| Feature | iOS | Android | Description |
|---------|-----|---------|-------------|
| **Model Loading** | ✅ | ✅ | Load USDZ (iOS) or GLB (Android) 3D models |
| **Model Placement** | ✅ | ✅ | Place models in AR space at specific coordinates |
| **Model Manipulation** | ✅ | ✅ | Scale, rotate, and translate models |
| **Screenshot** | ✅ | ✅ | Capture AR scene as base64 image |
| **Position Detection** | ✅ | ✅ | Convert 2D tap to 3D world coordinates |
| **Distance Measurement** | ✅ | ✅ | Draw line and measure distance between points |
| **Text Placement** | ✅ | ✅ | Place colored text labels in AR space |
| **Plane Detection** | ✅ | ✅ | Detect horizontal/vertical/both planes |
| **Light Estimation** | ✅ | ✅ | Realistic lighting based on environment |
| **Depth Management** | ✅ | ✅ | Occlusion and depth handling |

---

## File Structure

```
react-native-ar-main/
│
├── src/
│   └── index.tsx                    # Main React Native component
│
├── ios/
│   ├── ArViewerViewManager.swift    # iOS view manager
│   ├── ArViewerView.swift           # iOS view wrapper
│   ├── ModelARView.swift            # Main AR view implementation
│   ├── RealityKitViewController.swift
│   ├── DistanceUnit.swift           # Distance measurement utilities
│   └── Grid.swift                   # Grid overlay
│
├── android/
│   └── src/
│       └── main/
│           └── java/com/arviewer/
│               ├── ArViewerViewManager.kt
│               ├── ArViewerView.kt
│               └── [SceneView integration]
│
├── example/
│   └── src/
│       └── App.tsx                  # Example implementation
│
└── docs/                            # Documentation
```

---

## Command Flow

### **Available Commands**

```mermaid
graph TD
    Commands[UIManager Commands]
    
    Commands --> Screenshot[takeScreenshot<br/>Returns: base64 image]
    Commands --> Reset[reset<br/>Resets model position]
    Commands --> Load[loadModel<br/>Loads 3D model]
    Commands --> Rotate[rotateModel<br/>Params: pitch, yaw, roll]
    Commands --> Place[placeModel<br/>Params: x, y, z]
    Commands --> Text[placeText<br/>Params: x, y, z, color, text]
    Commands --> Position[getPositionVector3<br/>Params: x, y<br/>Returns: {x, y, z}]
    Commands --> Distance[createLineAndGetDistance<br/>Params: pos1, pos2, color<br/>Returns: distance]
    
    style Screenshot fill:#b2ebf2
    style Position fill:#b2ebf2
    style Distance fill:#b2ebf2
    style Reset fill:#ffccbc
    style Load fill:#ffccbc
    style Rotate fill:#c5cae9
    style Place fill:#c5cae9
    style Text fill:#c5cae9
```

---

## Event System

### **Event Flow**

```mermaid
graph LR
    subgraph "Native Events"
        Started[onStarted]
        Ended[onEnded]
        Placed[onModelPlaced]
        Removed[onModelRemoved]
        Tap[onUserTap]
        Error[onError]
        Data[onDataReturned]
    end
    
    subgraph "React Native"
        Callbacks[Event Callbacks]
        Promises[Promise Resolution]
    end
    
    Started --> Callbacks
    Ended --> Callbacks
    Placed --> Callbacks
    Removed --> Callbacks
    Tap --> Callbacks
    Error --> Callbacks
    Data --> Promises
    
    style Started fill:#c8e6c9
    style Ended fill:#c8e6c9
    style Placed fill:#c8e6c9
    style Removed fill:#c8e6c9
    style Tap fill:#fff9c4
    style Error fill:#ffcdd2
    style Data fill:#b3e5fc
```

---

## Platform-Specific Implementation

### **iOS Stack**
```
App.tsx
  ↓
ArViewerView (React Native)
  ↓
ArViewerViewManager.swift (Bridge)
  ↓
ArViewerView.swift (UIView wrapper)
  ↓
ModelARView.swift (ARView implementation)
  ↓
RealityKit + ARKit (Apple Frameworks)
```

### **Android Stack**
```
App.tsx
  ↓
ArViewerView (React Native)
  ↓
ArViewerViewManager.kt (Bridge)
  ↓
ArViewerView.kt (View wrapper)
  ↓
SceneView (SceneView Android)
  ↓
ARCore (Google Framework)
```

---

## Key Technologies

| Layer | iOS | Android | React Native |
|-------|-----|---------|--------------|
| **Language** | Swift | Kotlin | TypeScript |
| **AR Framework** | ARKit + RealityKit | ARCore + SceneView | - |
| **3D Format** | USDZ | GLB/GLTF | - |
| **Bridge** | Objective-C Bridge | JNI Bridge | UIManager |
| **Permissions** | Camera (Info.plist) | Camera (Manifest) | PermissionsAndroid |

---

## Example Usage Flow

```mermaid
sequenceDiagram
    participant U as User
    participant A as App.tsx
    participant AR as ArViewerView
    participant N as Native Module
    
    U->>A: Opens app
    A->>AR: Initialize with model path
    AR->>N: Request camera permission
    N-->>AR: Permission granted
    AR->>N: Load model
    N-->>AR: onStarted event
    
    U->>A: Taps screen
    A->>AR: onUserTap(x, y)
    AR->>N: getPositionVector3(x, y)
    N-->>AR: Returns {x, y, z}
    AR->>N: placeModel(x, y, z)
    N-->>AR: onModelPlaced event
    
    U->>A: Clicks "Take Snapshot"
    A->>AR: takeScreenshot()
    AR->>N: Capture scene
    N-->>AR: Returns base64 image
    AR-->>A: Save to file system
```

---

## Summary

This React Native AR Viewer library provides a **cross-platform AR solution** that:

- ✅ Bridges React Native with native AR frameworks (ARKit for iOS, ARCore for Android)
- ✅ Supports 3D model loading, placement, and manipulation
- ✅ Enables distance measurement and text annotation in AR space
- ✅ Provides real-time interaction through tap detection and position tracking
- ✅ Handles platform-specific implementations transparently
- ✅ Uses promise-based async communication for complex operations
- ✅ Implements proper permission handling for camera access

The architecture follows React Native best practices with a clear separation between the JavaScript layer, bridge layer, and native implementations.
