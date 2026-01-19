"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.ArViewerView = void 0;
var _react = _interopRequireWildcard(require("react"));
var _reactNative = require("react-native");
function _interopRequireWildcard(e, t) { if ("function" == typeof WeakMap) var r = new WeakMap(), n = new WeakMap(); return (_interopRequireWildcard = function (e, t) { if (!t && e && e.__esModule) return e; var o, i, f = { __proto__: null, default: e }; if (null === e || "object" != typeof e && "function" != typeof e) return f; if (o = t ? n : r) { if (o.has(e)) return o.get(e); o.set(e, f); } for (const t in e) "default" !== t && {}.hasOwnProperty.call(e, t) && ((i = (o = Object.defineProperty) && Object.getOwnPropertyDescriptor(e, t)) && (i.get || i.set) ? o(f, t, i) : f[t] = e[t]); return f; })(e, t); }
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const LINKING_ERROR = `The package 'react-native-ar-viewer' doesn't seem to be linked. Make sure: \n\n` + _reactNative.Platform.select({
  ios: "- You have run 'pod install'\n",
  default: ''
}) + '- You rebuilt the app after installing the package\n' + '- You are not using Expo managed workflow\n';
const ComponentName = 'ArViewerView';
const ArViewerComponent = _reactNative.UIManager.getViewManagerConfig(ComponentName) != null ? (0, _reactNative.requireNativeComponent)(ComponentName) : () => {
  throw new Error(LINKING_ERROR);
};
class ArViewerView extends _react.Component {
  // We need to keep track of all running requests, so we store a counter.
  _nextRequestId = 1;
  // We also need to keep track of all the promises we created so we can
  // resolve them later.
  _requestMap = new Map();
  // Add a ref to the native view component

  constructor(props) {
    super(props);
    this.state = {
      cameraPermission: _reactNative.Platform.OS !== 'android'
    };
    //@ts-ignore
    this.nativeRef = /*#__PURE__*/(0, _react.createRef)();
    // bind methods to current context
    this._onDataReturned = this._onDataReturned.bind(this);
    this._onError = this._onError.bind(this);
  }
  componentDidMount() {
    if (!this.state.cameraPermission) {
      // asks permissions internally to correct a bug: https://github.com/SceneView/sceneview-android/issues/80
      _reactNative.PermissionsAndroid.request(_reactNative.PermissionsAndroid.PERMISSIONS.CAMERA, {
        title: 'Cool Photo App Camera Permission',
        message: 'Cool Photo App needs access to your camera ' + 'so you can take awesome pictures.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK'
      }).then(granted => {
        if (granted === _reactNative.PermissionsAndroid.RESULTS.GRANTED) {
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
    this.nativeRef.current && _reactNative.UIManager.dispatchViewManagerCommand((0, _reactNative.findNodeHandle)(this.nativeRef.current), _reactNative.UIManager[ComponentName].Commands.takeScreenshot, [requestId]);
    return promise;
  }

  /**
   * Reset the model positionning
   * @returns void
   */
  reset() {
    this.nativeRef.current && _reactNative.UIManager.dispatchViewManagerCommand((0, _reactNative.findNodeHandle)(this.nativeRef.current), _reactNative.UIManager[ComponentName].Commands.reset, []);
  }

  /**
   * Loads the model
   * @returns void
   */
  loadModel() {
    this.nativeRef.current && _reactNative.UIManager.dispatchViewManagerCommand((0, _reactNative.findNodeHandle)(this.nativeRef.current), _reactNative.UIManager[ComponentName].Commands.loadModel, []);
  }

  /**
   * Rotate the model
   * @returns void
   */
  rotate(pitch, yaw, roll) {
    this.nativeRef.current && _reactNative.UIManager.dispatchViewManagerCommand((0, _reactNative.findNodeHandle)(this.nativeRef.current), _reactNative.UIManager[ComponentName].Commands.rotateModel, [pitch, yaw, roll]);
  }

  /**
   * Places the model
   * @returns void
   */
  placeModel(x, y, z) {
    this.nativeRef.current && _reactNative.UIManager.dispatchViewManagerCommand((0, _reactNative.findNodeHandle)(this.nativeRef.current), _reactNative.UIManager[ComponentName].Commands.placeModel, [x, y, z]);
  }
  placeText(x, y, z, color, text) {
    this.nativeRef.current && _reactNative.UIManager.dispatchViewManagerCommand((0, _reactNative.findNodeHandle)(this.nativeRef.current), _reactNative.UIManager[ComponentName].Commands.placeText, [x, y, z, color, text]);
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
    this.nativeRef.current && _reactNative.UIManager.dispatchViewManagerCommand((0, _reactNative.findNodeHandle)(this.nativeRef.current), _reactNative.UIManager[ComponentName].Commands.getPositionVector3, [x, y, requestId]);
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
    this.nativeRef.current && _reactNative.UIManager.dispatchViewManagerCommand((0, _reactNative.findNodeHandle)(this.nativeRef.current), _reactNative.UIManager[ComponentName].Commands.createLineAndGetDistance, [pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, color, requestId]);
    return promise;
  }
  render() {
    return this.state.cameraPermission && /*#__PURE__*/_react.default.createElement(ArViewerComponent, _extends({
      ref: this.nativeRef,
      onDataReturned: this._onDataReturned,
      onError: this._onError
    }, this.props));
  }
}
exports.ArViewerView = ArViewerView;
//# sourceMappingURL=index.js.map