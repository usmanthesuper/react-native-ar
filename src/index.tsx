import React, { Component, createRef, RefObject, SyntheticEvent } from 'react';
import {
  findNodeHandle,
  HostComponent,
  PermissionsAndroid,
  Platform,
  requireNativeComponent,
  UIManager,
  ViewStyle,
} from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-ar-viewer' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

type ArEvent = SyntheticEvent<
  {},
  {
    requestId: number | string;
    result: string;
    error: string;
  }
>;
type ArErrorEvent = SyntheticEvent<{}, { message: string }>;
type ArTapEvent = SyntheticEvent<{}, { coordinates: any }>;
type ArStatelessEvent = SyntheticEvent<{}, {}>;

type PositionVector3 = { x: number, y: number, z: number }


type ArViewerProps = {
  model?: string;
  planeOrientation?: 'none' | 'vertical' | 'horizontal' | 'both';
  allowScale?: boolean;
  allowRotate?: boolean;
  allowTranslate?: boolean;
  lightEstimation?: boolean;
  manageDepth?: boolean;
  disableInstructions?: boolean;
  disableInstantPlacement?: boolean;
  style?: ViewStyle;
  ref?: RefObject<HostComponent<ArViewerProps> | (() => never)>;
  onDataReturned: (e: ArEvent) => void;
  onError?: (e: ArErrorEvent) => void | undefined;
  onUserTap?: (e: ArTapEvent) => void | undefined;
  onStarted?: (e: ArStatelessEvent) => void | undefined;
  onEnded?: (e: ArStatelessEvent) => void | undefined;
  onModelPlaced?: (e: ArStatelessEvent) => void | undefined;
  onModelRemoved?: (e: ArStatelessEvent) => void | undefined;
};

type UIManagerArViewer = {
  Commands: {
    takeScreenshot: number;
    getPositionVector3: number;
    createLineAndGetDistance: number;
    reset: number;
    loadModel: number;
    rotateModel: number;
    placeModel: number;
    placeText: number;
  };
};

type ArViewUIManager = UIManager & {
  ArViewerView: UIManagerArViewer;
};

type ArInnerViewProps = Omit<
  ArViewerProps,
  'onDataReturned' | 'ref' | 'onError'
>;

type ArInnerViewState = {
  cameraPermission: boolean;
};

const ComponentName = 'ArViewerView';

const ArViewerComponent =
  UIManager.getViewManagerConfig(ComponentName) != null
    ? requireNativeComponent<ArViewerProps>(ComponentName)
    : () => {
      throw new Error(LINKING_ERROR);
    };

export class ArViewerView extends Component<
  ArInnerViewProps,
  ArInnerViewState
> {
  // We need to keep track of all running requests, so we store a counter.
  private _nextRequestId = 1;
  // We also need to keep track of all the promises we created so we can
  // resolve them later.
  private _requestMap = new Map<
    number,
    {
      resolve: (result: string) => void;
      reject: (result: string) => void;
    }
  >();
  // Add a ref to the native view component
  private nativeRef: RefObject<HostComponent<ArViewerProps> | (() => never)>;

  constructor(props: ArInnerViewProps) {
    super(props);
    this.state = {
      cameraPermission: Platform.OS !== 'android',
    };
    //@ts-ignore
    this.nativeRef = createRef<typeof ArViewerComponent>();
    // bind methods to current context
    this._onDataReturned = this._onDataReturned.bind(this);
    this._onError = this._onError.bind(this);
  }

  componentDidMount() {
    if (!this.state.cameraPermission) {
      // asks permissions internally to correct a bug: https://github.com/SceneView/sceneview-android/issues/80
      PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.CAMERA, {
        title: 'Cool Photo App Camera Permission',
        message:
          'Cool Photo App needs access to your camera ' +
          'so you can take awesome pictures.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK',
      }).then((granted) => {
        if (granted === PermissionsAndroid.RESULTS.GRANTED) {
          this.setState({ cameraPermission: true });
        } else {
          this._onError({
            nativeEvent: {
              message: 'Cannot start without camera permission',
            },
          } as ArErrorEvent);
        }
      });
    }
  }

  _onDataReturned(event: ArEvent) {
    // We grab the relevant data out of our event.
    const { result, error } = event.nativeEvent;
    const requestId = parseInt(event.nativeEvent.requestId as string, 10);
    // Then we get the promise we saved earlier for the given request ID.
    const promise = this._requestMap.get(requestId);
    if (promise) {
      if (result) {
        // If it was successful, we resolve the promise.
        promise.resolve(result);
      } else {
        // Otherwise, we reject it.
        promise.reject(error);
      }
      // Finally, we clean up our request map.
      this._requestMap.delete(requestId);
    }
  }

  _onError(event: ArErrorEvent) {
    // We grab the relevant data out of our event.
    const { message } = event.nativeEvent;
    console.warn(message);
  }

  /**
   * Takes a full screenshot of the rendered camera
   * @returns A promise resolving a base64 encoded image
   */
  takeScreenshot() {
    // Grab a new request ID and our request map.
    let requestId = this._nextRequestId++;
    let requestMap = this._requestMap;

    // We create a promise here that will be resolved once `_onRequestDone` is
    // called.
    let promise = new Promise<string>(function (resolve, reject) {
      requestMap.set(requestId, { resolve: resolve, reject: reject });
    });

    // Now just dispatch the command as before, adding the request ID to the
    // parameters.
    this.nativeRef.current &&
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(this.nativeRef.current as unknown as number),
        (UIManager as ArViewUIManager)[ComponentName].Commands.takeScreenshot,
        [requestId]
      );
    return promise;
  }

  /**
   * Reset the model positionning
   * @returns void
   */
  reset() {
    this.nativeRef.current &&
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(this.nativeRef.current as unknown as number),
        (UIManager as ArViewUIManager)[ComponentName].Commands.reset,
        []
      );
  }

  /**
   * Loads the model
   * @returns void
   */
  loadModel() {
    this.nativeRef.current &&
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(this.nativeRef.current as unknown as number),
        (UIManager as ArViewUIManager)[ComponentName].Commands.loadModel,
        []
      );
  }

  /**
   * Rotate the model
   * @returns void
   */
  rotate(pitch: number, yaw: number, roll: number) {
    this.nativeRef.current &&
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(this.nativeRef.current as unknown as number),
        (UIManager as ArViewUIManager)[ComponentName].Commands.rotateModel,
        [pitch, yaw, roll]
      );
  }

  /**
   * Places the model
   * @returns void
   */
  placeModel(x: number, y: number, z: number) {
    this.nativeRef.current &&
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(this.nativeRef.current as unknown as number),
        (UIManager as ArViewUIManager)[ComponentName].Commands.placeModel,
        [x, y, z]
      );
  }
  
  placeText(x: number, y: number, z: number, color: string, text: string) {
    this.nativeRef.current &&
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(this.nativeRef.current as unknown as number),
        (UIManager as ArViewUIManager)[ComponentName].Commands.placeText,
        [x, y, z, color, text]
      );
  }

  /**
   * Returns vector 3 postion from x and y co-ords
   * @returns void
   */
  getPositionVector3(x: number, y: number) {
    // Grab a new request ID and our request map.
    let requestId = this._nextRequestId++;
    let requestMap = this._requestMap;

    // We create a promise here that will be resolved once `_onRequestDone` is
    // called.
    let promise = new Promise<any>(function (resolve, reject) {
      requestMap.set(requestId, { resolve: resolve, reject: reject });
    });

    // Now just dispatch the command as before, adding the request ID to the
    // parameters.
    this.nativeRef.current &&
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(this.nativeRef.current as unknown as number),
        (UIManager as ArViewUIManager)[ComponentName].Commands.getPositionVector3,
        [x, y, requestId]
      );
    return promise;
  }

  createLineAndGetDistance(pos1: PositionVector3, pos2: PositionVector3, color: string) {
    // Grab a new request ID and our request map.
    let requestId = this._nextRequestId++;
    let requestMap = this._requestMap;

    // We create a promise here that will be resolved once `_onRequestDone` is
    // called.
    let promise = new Promise<string>(function (resolve, reject) {
      requestMap.set(requestId, { resolve: resolve, reject: reject });
    });

    // Now just dispatch the command as before, adding the request ID to the
    // parameters.
    this.nativeRef.current &&
      UIManager.dispatchViewManagerCommand(
        findNodeHandle(this.nativeRef.current as unknown as number),
        (UIManager as ArViewUIManager)[ComponentName].Commands.createLineAndGetDistance,
        [pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, color, requestId]
      );
    return promise;
  }


  render() {
    return (
      this.state.cameraPermission && (
        <ArViewerComponent
          ref={this.nativeRef}
          onDataReturned={this._onDataReturned}
          onError={this._onError}
          {...this.props}
        />
      )
    );
  }
}
