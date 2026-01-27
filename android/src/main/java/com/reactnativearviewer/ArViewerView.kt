package com.reactnativearviewer

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.Base64
import android.util.Log
import android.view.GestureDetector
import android.view.GestureDetector.SimpleOnGestureListener
import android.view.Gravity
import android.view.MotionEvent
import android.view.PixelCopy
import android.view.ViewGroup
import android.view.ViewTreeObserver.OnWindowFocusChangeListener
import android.widget.FrameLayout
import android.widget.TextView
import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.events.RCTEventEmitter
import com.google.android.filament.utils.Float3
import com.google.ar.core.*
import com.google.ar.core.ArCoreApk.InstallStatus
import com.google.ar.core.exceptions.UnavailableException
import com.google.ar.sceneform.*
import com.google.ar.sceneform.math.Quaternion
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.rendering.CameraStream
import com.google.ar.sceneform.rendering.ModelRenderable
import com.google.ar.sceneform.rendering.ViewRenderable
import com.google.ar.sceneform.ux.BaseArFragment.OnSessionConfigurationListener
import com.google.ar.sceneform.ux.FootprintSelectionVisualizer
import com.google.ar.sceneform.ux.TransformableNode
import com.google.ar.sceneform.ux.TransformationSystem
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.*
import kotlin.math.sqrt


class ArViewerView @JvmOverloads constructor(
  context: ThemedReactContext, attrs: AttributeSet? = null, defStyleAttr: Int = 0
): FrameLayout(context, attrs, defStyleAttr), Scene.OnPeekTouchListener, Scene.OnUpdateListener {
  /**
   * We show only one model, let's store the ref here
   */
  private var modelNode: CustomTransformableNode? = null
  /**
   * Our main view that integrates with ARCore and renders a scene
   */
  private var arView: ArSceneView? = null
  /**
   * Event listener that triggers on focus
   */
  private val onFocusListener = OnWindowFocusChangeListener { onWindowFocusChanged(it) }
  /**
   * Event listener that triggers when the ARCore Session is to be configured
   */
  private val onSessionConfigurationListener: OnSessionConfigurationListener? = null

  /**
   * Main view state
   */
  private var isStarted = false
  /**
   * ARCore installation requirement state
   */
  private var installRequested = false
  /**
   * Failed session initialization state
   */
  private var sessionInitializationFailed = false
  /**
   * Depth management enabled state
   */
  private var isDepthManagementEnabled = false
  /**
   * Light estimation enabled state
   */
  private var isLightEstimationEnabled = false
  /**
   * Instant placement enabled state
   */
  private var isInstantPlacementEnabled = true
  /**
   * Plane orientation mode
   */
  private var planeOrientationMode: String = "both"
  /**
   * Instructions enabled state
   */
  private var isInstructionsEnabled = true
  /**
   * Device supported state
   */
  private var isDeviceSupported = true
  /**
   * Reminder to keep track of model loading state
   */
  private var isLoading = false

  /**
   * Config of the main session initialization
   */
  private var sessionConfig: Config? = null
  /**
   * AR session initialization
   */
  private var arSession: Session? = null
  /**
   * Instructions controller initialization
   */
  private var instructionsController: InstructionsController? = null
  /**
   * Transformation system initialization
   */
  private var transformationSystem: TransformationSystem? = null
  /**
   * Gesture detector initialization
   */
  private var gestureDetector: GestureDetector? = null

  /**
   * Reminder to keep source of model loading
   */
  private var modelSrc: String = ""
  /**
   * Set of allowed model transformations (rotate, scale, translate...)
   */
  private var allowTransform = mutableSetOf<String>()

  init {
    if (checkIsSupportedDevice(context.currentActivity!!)) {
      // check AR Core installation
      if (requestInstall()) {
        returnErrorEvent("ARCore installation required")
        isDeviceSupported = false
      } else {
        // let's create sceneform view
        arView = ArSceneView(context, attrs)
        arView!!.layoutParams = LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        this.addView(arView)

        transformationSystem = makeTransformationSystem()

        gestureDetector = GestureDetector(
          context,
          object : SimpleOnGestureListener() {
            override fun onSingleTapUp(e: MotionEvent): Boolean {
              onSingleTap(e)
              return true
            }

            override fun onDown(e: MotionEvent): Boolean {
              return true
            }
          })

        arView!!.scene.addOnPeekTouchListener(this)
        arView!!.scene.addOnUpdateListener(this)
        arView!!.viewTreeObserver.addOnWindowFocusChangeListener(onFocusListener)
        arView!!.setOnSessionConfigChangeListener(this::onSessionConfigChanged)

        val session = Session(context)
        val config = Config(session)

        // Set plane orientation mode
        updatePlaneDetection(config)
        // Enable or not light estimation
        updateLightEstimation(config)
        // Enable or not depth management
        updateDepthManagement(config)

        // Sets the desired focus mode
        config.focusMode = Config.FocusMode.AUTO
        // Force the non-blocking mode for the session.
        config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE

        sessionConfig = config
        arSession = session
        arView!!.session?.configure(sessionConfig)
        arView!!.session = arSession

        initializeSession()
        resume()

        // Setup the instructions view.
        instructionsController = InstructionsController(context, this);
        instructionsController!!.setEnabled(isInstructionsEnabled);
      }
    } else {
      isDeviceSupported = false
    }
  }

  private fun resume() {
    if (isStarted) {
      return
    }
    if ((context as ThemedReactContext).currentActivity != null) {
      isStarted = true
      try {
        arView!!.resume()
      } catch (ex: java.lang.Exception) {
        sessionInitializationFailed = true
        returnErrorEvent("Could not resume session")
      }
      if (!sessionInitializationFailed) {
        instructionsController?.setVisible(true)
      }
    }
  }

  /**
   * Initializes the ARCore session. The CAMERA permission is checked before checking the
   * installation state of ARCore. Once the permissions and installation are OK, the method
   * #getSessionConfiguration(Session session) is called to get the session configuration to use.
   * Sceneform requires that the ARCore session be updated using LATEST_CAMERA_IMAGE to avoid
   * blocking while drawing. This mode is set on the configuration object returned from the
   * subclass.
   */
  private fun initializeSession() {
    // Only try once
    if (sessionInitializationFailed) {
      return
    }
    // if we have the camera permission, create the session
    if (CameraPermissionHelper.hasCameraPermission((context as ThemedReactContext).currentActivity)) {
      val sessionException: UnavailableException?
      try {
        onSessionConfigurationListener?.onSessionConfiguration(arSession, sessionConfig)

        // run a JS event
        Log.d("ARview session", "started")
        val event = Arguments.createMap()
        val reactContext = context as ThemedReactContext
        reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(
          id,
          "onStarted",
          event
        )

        return
      } catch (e: UnavailableException) {
        sessionException = e
      } catch (e: java.lang.Exception) {
        sessionException = UnavailableException()
        sessionException.initCause(e)
      }
      sessionInitializationFailed = true
      returnErrorEvent(sessionException?.message)
    } else {
      returnErrorEvent("Missing camera permissions")
    }
  }

  /**
   * Removed the focus listener
   */
  fun onDrop() {
    if(arView != null) {
      arView!!.pause()
      arView!!.session?.close()
      arView!!.destroy()
      arView!!.viewTreeObserver.removeOnWindowFocusChangeListener(onFocusListener)
    }
  }

  /**
   * Occurs when a session configuration has changed.
   */
  private fun onSessionConfigChanged(config: Config) {
    instructionsController?.setEnabled(
      config.planeFindingMode !== Config.PlaneFindingMode.DISABLED
    )
  }

  /**
   * Creates the transformation system used by this view.
   */
  private fun makeTransformationSystem(): TransformationSystem {
    val selectionVisualizer = FootprintSelectionVisualizer()
    return TransformationSystem(resources.displayMetrics, selectionVisualizer)
  }

  /**
   * Makes the transformation system responding to touches
   */
  override fun onPeekTouch(hitTestResult: HitTestResult, motionEvent: MotionEvent?) {
    transformationSystem!!.onTouch(hitTestResult, motionEvent)
    if (hitTestResult.node == null && motionEvent != null) {
      gestureDetector!!.onTouchEvent(motionEvent)
    }
  }

  /**
   * On each frame
   */
  override fun onUpdate(frameTime: FrameTime?) {
    if (arView!!.session == null || arView!!.arFrame == null) return
    if (instructionsController != null) {
      // Instructions for the Plane finding mode.
      val showPlaneInstructions: Boolean = !arView!!.hasTrackedPlane()
      if (instructionsController?.isVisible() != showPlaneInstructions) {
        instructionsController?.setVisible(
          showPlaneInstructions
        )
      }
    }

    if (isInstantPlacementEnabled && arView!!.arFrame?.camera?.trackingState == TrackingState.TRACKING) {
      // Check if there is already an anchor
      if (modelNode?.parent is AnchorNode) {
        return
      }

      // Create the Anchor.
      val pos = floatArrayOf(0f, 0f, -1f)
      val rotation = floatArrayOf(0f, 0f, 0f, 1f)
      val anchor: Anchor = arView!!.session!!.createAnchor(Pose(pos, rotation))
      initAnchorNode(anchor)

      // tells JS that the model is visible
      onModelPlaced()
    }
  }

  fun onSingleTap(motionEvent: MotionEvent?) {
    if (arView != null && motionEvent != null) {
      // Fire onUserTap event with screen coordinates
      val event = Arguments.createMap()
      val coordinates = Arguments.createMap()
      coordinates.putDouble("x", motionEvent.x.toDouble())
      coordinates.putDouble("y", motionEvent.y.toDouble())
      event.putMap("coordinates", coordinates)

      val reactContext = context as ThemedReactContext
      reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(
        id,
        "onUserTap",
        event
      )

      Log.d("ARview onUserTap", "Tap at x=${motionEvent.x}, y=${motionEvent.y}")
    }
  }

  private fun initAnchorNode(anchor: Anchor) {
    val anchorNode = AnchorNode(anchor)

    anchorNode.parent = arView!!.scene
    modelNode!!.parent = anchorNode

    // Animate if has animation
    val renderableInstance = modelNode?.renderableInstance
    if (renderableInstance != null && renderableInstance.hasAnimations()) {
      renderableInstance.animate(true).start()
    }
  }

  private fun onModelPlaced() {
    val event = Arguments.createMap()
    val reactContext = context as ThemedReactContext
    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(
      id,
      "onModelPlaced",
      event
    )
  }

  /**
   * Request ARCore installation
   */
  private fun requestInstall(): Boolean {
    when (ArCoreApk.getInstance().requestInstall((context as ThemedReactContext).currentActivity, !installRequested)) {
      InstallStatus.INSTALL_REQUESTED -> {
        installRequested = true
        return true
      }
      InstallStatus.INSTALLED -> {}
    }
    return false
  }

  /**
   * Set plane detection orientation
   */
  fun setPlaneDetection(planeOrientation: String) {
    planeOrientationMode = planeOrientation
    sessionConfig.let {
      updatePlaneDetection(sessionConfig)
      updateConfig()
    }
  }

  private fun updatePlaneDetection(config: Config?) {
    when (planeOrientationMode) {
      "horizontal" -> {
        config?.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
        if (modelNode != null) {
          modelNode!!.translationController.allowedPlaneTypes.clear()
          modelNode!!.translationController.allowedPlaneTypes.add(Plane.Type.HORIZONTAL_DOWNWARD_FACING)
          modelNode!!.translationController.allowedPlaneTypes.add(Plane.Type.HORIZONTAL_UPWARD_FACING)
        }
      }
      "vertical" -> {
        config?.planeFindingMode = Config.PlaneFindingMode.VERTICAL
        if (modelNode != null) {
          modelNode!!.translationController.allowedPlaneTypes.clear()
          modelNode!!.translationController.allowedPlaneTypes.add(Plane.Type.VERTICAL)
        }
      }
      "both" -> {
        config?.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
        if (modelNode != null) {
          modelNode!!.translationController.allowedPlaneTypes.clear()
          modelNode!!.translationController.allowedPlaneTypes = EnumSet.allOf(Plane.Type::class.java)
        }
      }
      "none" -> {
        config?.planeFindingMode = Config.PlaneFindingMode.DISABLED
        if (modelNode != null) {
          modelNode!!.translationController.allowedPlaneTypes.clear()
        }
      }
    }
  }

  /**
   * Set whether instant placement is enabled
   */
  fun setInstantPlacementEnabled(isEnabled: Boolean) {
    isInstantPlacementEnabled = isEnabled
  }

  /**
   * Set whether light estimation is enabled
   */
  fun setLightEstimationEnabled(isEnabled: Boolean) {
    isLightEstimationEnabled = isEnabled
    sessionConfig.let {
      updateLightEstimation(sessionConfig)
      updateConfig()
    }
  }

  private fun updateLightEstimation(config: Config?) {
    if(!isLightEstimationEnabled) {
      config?.lightEstimationMode = Config.LightEstimationMode.DISABLED
    } else {
      config?.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
    }
  }

  /**
   * Set whether depth management is enabled
   */
  fun setDepthManagementEnabled(isEnabled: Boolean) {
    isDepthManagementEnabled = isEnabled
    sessionConfig.let {
      updateDepthManagement(sessionConfig)
      updateConfig()
    }
  }

  private fun updateDepthManagement(config: Config?) {
    if (!isDepthManagementEnabled) {
      sessionConfig?.depthMode = Config.DepthMode.DISABLED
      arView?.cameraStream?.depthOcclusionMode = CameraStream.DepthOcclusionMode.DEPTH_OCCLUSION_DISABLED
    } else {
      if(arSession?.isDepthModeSupported(Config.DepthMode.AUTOMATIC) == true) {
        sessionConfig?.depthMode = Config.DepthMode.AUTOMATIC
      }
      arView?.cameraStream?.depthOcclusionMode = CameraStream.DepthOcclusionMode.DEPTH_OCCLUSION_ENABLED
    }
  }

  private fun updateConfig() {
    if (isStarted) {
      arSession?.configure(sessionConfig)
    }
  }

  /**
   * Start the loading of a GLB model URI
   */
  fun loadModel(src: String) {
    if (isDeviceSupported) {
      if (modelNode?.parent is AnchorNode) {
        Log.d("ARview model", "detaching")
        (modelNode!!.parent as AnchorNode).anchor?.detach() // free up memory of anchor
        arView?.scene?.removeChild(modelNode)
        modelNode = null
        val event = Arguments.createMap()
        val reactContext = context as ThemedReactContext
        reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(
          id,
          "onModelRemoved",
          event
        )
      }
      Log.d("ARview model", "loading")
      modelSrc = src
      isLoading = true

      ModelRenderable.builder()
        .setSource(context, Uri.parse(src))
        .setIsFilamentGltf(true)
        .build()
        .thenAccept {
          modelNode = CustomTransformableNode(transformationSystem!!)
          modelNode!!.select()
          modelNode!!.renderable = it
          // set model at center
          modelNode!!.renderableInstance.filamentAsset.let { asset ->
            val center = asset!!.boundingBox.center.let { v -> Float3(v[0], v[1], v[2]) }
            val halfExtent = asset.boundingBox.halfExtent.let { v -> Float3(v[0], v[1], v[2]) }
            val fCenter = -(center + halfExtent * Float3(0f, -1f, 1f)) * Float3(1f, 1f, 1f)
            modelNode!!.localPosition = Vector3(fCenter.x, fCenter.y, fCenter.z)
          }

          Log.d("ARview model", "loaded")
          isLoading = false

          // set transforms on model
          onTransformChanged()
        }
        .exceptionally {
          Log.e("ARview model", "cannot load")
          returnErrorEvent("Cannot load the model: " + it.message)
          return@exceptionally null
        }
    }
  }

  /**
   * Rotate the model with the requested angle
   */
  fun rotateModel(pitch: Number, yaw: Number, roll:Number) {
    Log.d("ARview rotateModel", "pitch: $pitch deg / yaw: $yaw deg / roll: $roll deg")
    modelNode?.localRotation = Quaternion.multiply(modelNode?.localRotation, Quaternion.eulerAngles(Vector3(pitch.toFloat(), yaw.toFloat(), roll.toFloat())))
  }

  /**
   * Remove the model from the view and reset plane detection
   */
  fun resetModel() {
    Log.d("ARview model", "Resetting model")
    if (modelNode != null) {
      loadModel(modelSrc)
    }
  }

  /**
   * Add a transformation to the allowed list
   */
  fun addAllowTransform(transform: String) {
    allowTransform.add(transform)
    onTransformChanged()
  }

  /**
   * Remove a transformation to the allowed list
   */
  fun removeAllowTransform(transform: String) {
    allowTransform.remove(transform)
    onTransformChanged()
  }

  private fun onTransformChanged() {
    if (modelNode == null) return
    modelNode!!.scaleController.isEnabled = allowTransform.contains("scale")
    modelNode!!.rotationController.isEnabled = allowTransform.contains("rotate")
    modelNode!!.translationController.isEnabled = allowTransform.contains("translate")
  }

  /**
   * Enable/Disable instructions
   */
  fun setInstructionsEnabled(isEnabled: Boolean) {
    isInstructionsEnabled = isEnabled
    instructionsController?.setEnabled(isInstructionsEnabled)
  }

  /**
   * Takes a screenshot of the view and send it to JS through event
   */
  fun takeScreenshot(requestId: Int) {
    Log.d("ARview takeScreenshot", requestId.toString())

    val bitmap = Bitmap.createBitmap(
      width, height,
      Bitmap.Config.ARGB_8888
    )
    var encodedImage: String? = null
    var encodedImageError: String? = null
    PixelCopy.request(arView!!, bitmap, { copyResult ->
      if (copyResult == PixelCopy.SUCCESS) {
        try {
          val byteArrayOutputStream = ByteArrayOutputStream()
          bitmap.compress(Bitmap.CompressFormat.JPEG, 70, byteArrayOutputStream)
          val byteArray = byteArrayOutputStream.toByteArray()
          val encoded = Base64.encodeToString(byteArray, Base64.DEFAULT)
          encodedImage = encoded
          Log.d("ARview takeScreenshot", "success")
        } catch (e: Exception) {
          encodedImageError = "The image cannot be saved: " + e.localizedMessage
          Log.d("ARview takeScreenshot", "fail")
        }
        returnDataEvent(requestId, encodedImage, encodedImageError)
      }
    }, Handler(Looper.getMainLooper()))
  }

  /**
   * Send back an event to JS
   */
  private fun returnDataEvent(requestId: Int, result: String?, error: String?) {
    val event = Arguments.createMap()
    event.putString("requestId", requestId.toString())
    event.putString("result", result)
    event.putString("error", error)
    val reactContext = context as ThemedReactContext
    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(
      id,
      "onDataReturned",
      event
    )
  }

  /**
   * Send back an error event to JS
   */
  private fun returnErrorEvent(message: String?) {
    val event = Arguments.createMap()
    event.putString("message", message)
    val reactContext = context as ThemedReactContext
    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(
      id,
      "onError",
      event
    )
  }

  /**
   * Returns false and displays an error message if Sceneform can not run, true if Sceneform can run
   * on this device.
   *
   *
   * Sceneform requires Android N on the device as well as OpenGL 3.0 capabilities.
   *
   *
   * Finishes the activity if Sceneform can not run
   */
  private fun checkIsSupportedDevice(activity: Activity): Boolean {
    val openGlVersionString =
      (activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
        .deviceConfigurationInfo
        .glEsVersion
    if (openGlVersionString.toDouble() < 3.0) {
      returnErrorEvent("This feature requires OpenGL ES 3.0 later")
      return false
    }
    return true
  }

  /**
   * Manually load the model (wrapper for existing loadModel function)
   */
  fun loadModelManually() {
    Log.d("ARview loadModelManually", "Loading model: $modelSrc")
    if (modelSrc.isNotEmpty()) {
      loadModel(modelSrc)
    } else {
      returnErrorEvent("No model source specified")
    }
  }

  /**
   * Place model at specific 3D coordinates
   */
  fun placeModelAtPosition(x: Float, y: Float, z: Float) {
    Log.d("ARview placeModel", "Placing model at: x=$x, y=$y, z=$z")
    if (modelNode == null) {
      returnErrorEvent("No model loaded to place")
      return
    }

    try {
      // Create pose at specified position
      val pose = Pose(floatArrayOf(x, y, z), floatArrayOf(0f, 0f, 0f, 1f))

      // Create anchor at that pose
      val anchor = arView!!.session!!.createAnchor(pose)

      // Attach model to anchor
      initAnchorNode(anchor)

      // Notify JS that model was placed
      onModelPlaced()
    } catch (e: Exception) {
      Log.e("ARview placeModel", "Error placing model: ${e.message}")
      returnErrorEvent("Failed to place model: ${e.message}")
    }
  }

  /**
   * Place 3D text at specified coordinates
   */
  fun placeText(x: Float, y: Float, z: Float, color: String, text: String) {
    Log.d("ARview placeText", "Placing text '$text' at: x=$x, y=$y, z=$z, color=$color")

    try {
      val parsedColor = parseHexColor(color)

      // Create TextView
      ViewRenderable.builder()
        .setView(context, android.R.layout.simple_list_item_1)
        .build()
        .thenAccept { renderable ->
          // Configure the TextView
          val textView = renderable.view as TextView
          textView.text = text
          textView.setTextColor(parsedColor)
          textView.gravity = Gravity.CENTER
          textView.textSize = 4f
          textView.setBackgroundColor(Color.TRANSPARENT)

          // Create pose at specified position
          val pose = Pose(floatArrayOf(x, y, z), floatArrayOf(0f, 0f, 0f, 1f))

          // Create anchor
          val anchor = arView!!.session!!.createAnchor(pose)
          val anchorNode = AnchorNode(anchor)
          anchorNode.parent = arView!!.scene

          // Create node for text
          val textNode = Node()
          textNode.parent = anchorNode
          textNode.renderable = renderable
          textNode.localPosition = Vector3(0f, 0f, 0f)

          Log.d("ARview placeText", "Text placed successfully")
        }
        .exceptionally { throwable ->
          Log.e("ARview placeText", "Error creating text: ${throwable.message}")
          returnErrorEvent("Failed to create text: ${throwable.message}")
          null
        }
    } catch (e: Exception) {
      Log.e("ARview placeText", "Error: ${e.message}")
      returnErrorEvent("Failed to place text: ${e.message}")
    }
  }

  /**
   * Get 3D world position from 2D screen coordinates
   */
  fun getPositionVector3(x: Float, y: Float, requestId: Int) {
    Log.d("ARview getPositionVector3", "Getting position for screen coords: x=$x, y=$y")

    try {
      val frame = arView?.arFrame
      if (frame == null) {
        returnDataEvent(requestId, null, "AR frame not available")
        return
      }

      // Perform hit test at screen coordinates
      val hits = frame.hitTest(x, y)

      if (hits.isNotEmpty()) {
        val hit = hits[0]
        val pose = hit.hitPose

        // Create JSON with x, y, z coordinates
        val json = JSONObject()
        json.put("x", pose.tx().toDouble())
        json.put("y", pose.ty().toDouble())
        json.put("z", pose.tz().toDouble())
        Log.d("ARview getPositionVector3", "Position: ${json.toString()}")
        returnDataEvent(requestId, json.toString(), null)
      } else {
        returnDataEvent(requestId, null, "No surface detected at screen point")
      }
    } catch (e: Exception) {
      Log.e("ARview getPositionVector3", "Error: ${e.message}")
      returnDataEvent(requestId, null, "Failed to get position: ${e.message}")
    }
  }

  /**
   * Create a line between two points and return the distance
   */
  fun createLineAndGetDistance(
    x1: Float, y1: Float, z1: Float,
    x2: Float, y2: Float, z2: Float,
    color: String, requestId: Int
  ) {
    Log.d("ARview createLine", "Creating line from ($x1,$y1,$z1) to ($x2,$y2,$z2)")

    try {
      val start = Vector3(x1, y1, z1)
      val end = Vector3(x2, y2, z2)
      val parsedColor = parseHexColor(color)

      // Calculate distance
      val dx = x2 - x1
      val dy = y2 - y1
      val dz = z2 - z1
      val distance = sqrt(dx * dx + dy * dy + dz * dz)

      // Format distance (convert to cm or m)
      val distanceText = if (distance < 1.0f) {
        String.format("%.1f cm", distance * 100)
      } else {
        String.format("%.2f m", distance)
      }

      // Create line geometry
      createLineBetweenPoints(start, end, parsedColor)

      Log.d("ARview createLine", "Distance: $distanceText")
      returnDataEvent(requestId, distanceText, null)
    } catch (e: Exception) {
      Log.e("ARview createLine", "Error: ${e.message}")
      returnDataEvent(requestId, null, "Failed to create line: ${e.message}")
    }
  }

  /**
   * Helper: Parse hex color string to Android Color int
   */
  private fun parseHexColor(hex: String): Int {
    return try {
      var colorString = hex.trim()
      if (!colorString.startsWith("#")) {
        colorString = "#$colorString"
      }
      Color.parseColor(colorString)
    } catch (e: Exception) {
      Log.w("ARview parseColor", "Invalid color '$hex', using white")
      Color.WHITE
    }
  }

  /**
   * Helper: Create a line (cylinder) between two points
   */
  private fun createLineBetweenPoints(start: Vector3, end: Vector3, color: Int) {
    try {
      // Calculate midpoint
      val midpoint = Vector3.add(start, end).scaled(0.5f)

      // Calculate distance for cylinder height
      val distance = Vector3.subtract(end, start).length()

      // Create cylinder shape
      ModelRenderable.builder()
        .setSource(context, Uri.parse("https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Box/glTF/Box.gltf"))
        .build()
        .thenAccept { renderable ->
          // Create node for line
          val lineNode = Node()
          lineNode.parent = arView!!.scene
          lineNode.worldPosition = midpoint

          // Scale to make it a thin line
          lineNode.localScale = Vector3(0.005f, distance / 2, 0.005f)

          // Rotate to point from start to end
          val direction = Vector3.subtract(end, start).normalized()
          val up = Vector3.up()
          val rotation = Quaternion.lookRotation(direction, up)
          lineNode.localRotation = rotation

          lineNode.renderable = renderable

          // Apply color (this is simplified - proper material coloring would be more complex)
          Log.d("ARview createLine", "Line created")
        }
        .exceptionally { throwable ->
          Log.e("ARview createLine", "Error creating line geometry: ${throwable.message}")
          null
        }
    } catch (e: Exception) {
      Log.e("ARview createLine", "Error: ${e.message}")
    }
  }
}


