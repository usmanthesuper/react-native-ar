function _extends() { _extends = Object.assign ? Object.assign.bind() : function (target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i]; for (var key in source) { if (Object.prototype.hasOwnProperty.call(source, key)) { target[key] = source[key]; } } } return target; }; return _extends.apply(this, arguments); }
import React, { Component, createRef } from 'react';
import { findNodeHandle, PermissionsAndroid, Platform, requireNativeComponent, UIManager } from 'react-native';
const LINKING_ERROR = `The package 'react-native-ar-viewer' doesn't seem to be linked. Make sure: \n\n` + Platform.select({
  ios: "- You have run 'pod install'\n",
  default: ''
}) + '- You rebuilt the app after installing the package\n' + '- You are not using Expo managed workflow\n';
const ComponentName = 'ArViewerView';
const ArViewerComponent = UIManager.getViewManagerConfig(ComponentName) != null ? requireNativeComponent(ComponentName) : () => {
  throw new Error(LINKING_ERROR);
};
export class ArViewerView extends Component {
  // We need to keep track of all running requests, so we store a counter.
  _nextRequestId = 1;
  // We also need to keep track of all the promises we created so we can
  // resolve them later.
  _requestMap = new Map();
  // Add a ref to the native view component

  constructor(props) {
    super(props);
    this.state = {
      cameraPermission: Platform.OS !== 'android'
    };
    //@ts-ignore
    this.nativeRef = /*#__PURE__*/createRef();
    // bind methods to current context
    this._onDataReturned = this._onDataReturned.bind(this);
    this._onError = this._onError.bind(this);
  }
  componentDidMount() {
    if (!this.state.cameraPermission) {
      // asks permissions internally to correct a bug: https://github.com/SceneView/sceneview-android/issues/80
      PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.CAMERA, {
        title: 'Cool Photo App Camera Permission',
        message: 'Cool Photo App needs access to your camera ' + 'so you can take awesome pictures.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK'
      }).then(granted => {
        if (granted === PermissionsAndroid.RESULTS.GRANTED) {
          this.setState({
            cameraPermission: true
          });
        } else {
          this._onError({
            nativeEvent: {
              message: 'Cannot start without camera permission'
            }
          });
        }
      });
    }
  }
  _onDataReturned(event) {
    // We grab the relevant data out of our event.
    const {
      result,
      error
    } = event.nativeEvent;
    const requestId = parseInt(event.nativeEvent.requestId, 10);
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
  _onError(event) {
    // We grab the relevant data out of our event.
    const {
      message
    } = event.nativeEvent;
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
    let promise = new Promise(function (resolve, reject) {
      requestMap.set(requestId, {
        resolve: resolve,
        reject: reject
      });
    });

    // Now just dispatch the command as before, adding the request ID to the
    // parameters.
    this.nativeRef.current && UIManager.dispatchViewManagerCommand(findNodeHandle(this.nativeRef.current), UIManager[ComponentName].Commands.takeScreenshot, [requestId]);
    return promise;
  }

  /**
   * Reset the model positionning
   * @returns void
   */
  reset() {
    this.nativeRef.current && UIManager.dispatchViewManagerCommand(findNodeHandle(this.nativeRef.current), UIManager[ComponentName].Commands.reset, []);
  }

  /**
   * Loads the model
   * @returns void
   */
  loadModel() {
    this.nativeRef.current && UIManager.dispatchViewManagerCommand(findNodeHandle(this.nativeRef.current), UIManager[ComponentName].Commands.loadModel, []);
  }

  /**
   * Rotate the model
   * @returns void
   */
  rotate(pitch, yaw, roll) {
    this.nativeRef.current && UIManager.dispatchViewManagerCommand(findNodeHandle(this.nativeRef.current), UIManager[ComponentName].Commands.rotateModel, [pitch, yaw, roll]);
  }

  /**
   * Places the model
   * @returns void
   */
  placeModel(x, y, z) {
    this.nativeRef.current && UIManager.dispatchViewManagerCommand(findNodeHandle(this.nativeRef.current), UIManager[ComponentName].Commands.placeModel, [x, y, z]);
  }
  placeText(x, y, z, color, text) {
    this.nativeRef.current && UIManager.dispatchViewManagerCommand(findNodeHandle(this.nativeRef.current), UIManager[ComponentName].Commands.placeText, [x, y, z, color, text]);
  }

  /**
   * Returns vector 3 postion from x and y co-ords
   * @returns void
   */
  getPositionVector3(x, y) {
    // Grab a new request ID and our request map.
    let requestId = this._nextRequestId++;
    let requestMap = this._requestMap;

    // We create a promise here that will be resolved once `_onRequestDone` is
    // called.
    let promise = new Promise(function (resolve, reject) {
      requestMap.set(requestId, {
        resolve: resolve,
        reject: reject
      });
    });

    // Now just dispatch the command as before, adding the request ID to the
    // parameters.
    this.nativeRef.current && UIManager.dispatchViewManagerCommand(findNodeHandle(this.nativeRef.current), UIManager[ComponentName].Commands.getPositionVector3, [x, y, requestId]);
    return promise;
  }
  createLineAndGetDistance(pos1, pos2, color) {
    // Grab a new request ID and our request map.
    let requestId = this._nextRequestId++;
    let requestMap = this._requestMap;

    // We create a promise here that will be resolved once `_onRequestDone` is
    // called.
    let promise = new Promise(function (resolve, reject) {
      requestMap.set(requestId, {
        resolve: resolve,
        reject: reject
      });
    });

    // Now just dispatch the command as before, adding the request ID to the
    // parameters.
    this.nativeRef.current && UIManager.dispatchViewManagerCommand(findNodeHandle(this.nativeRef.current), UIManager[ComponentName].Commands.createLineAndGetDistance, [pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, color, requestId]);
    return promise;
  }
  render() {
    return this.state.cameraPermission && /*#__PURE__*/React.createElement(ArViewerComponent, _extends({
      ref: this.nativeRef,
      onDataReturned: this._onDataReturned,
      onError: this._onError
    }, this.props));
  }
}
//# sourceMappingURL=index.js.map