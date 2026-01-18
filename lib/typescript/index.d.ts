import React, { Component, RefObject, SyntheticEvent } from 'react';
import { HostComponent, ViewStyle } from 'react-native';
type ArEvent = SyntheticEvent<{}, {
    requestId: number | string;
    result: string;
    error: string;
}>;
type ArErrorEvent = SyntheticEvent<{}, {
    message: string;
}>;
type ArTapEvent = SyntheticEvent<{}, {
    coordinates: any;
}>;
type ArStatelessEvent = SyntheticEvent<{}, {}>;
type PositionVector3 = {
    x: number;
    y: number;
    z: number;
};
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
type ArInnerViewProps = Omit<ArViewerProps, 'onDataReturned' | 'ref' | 'onError'>;
type ArInnerViewState = {
    cameraPermission: boolean;
};
export declare class ArViewerView extends Component<ArInnerViewProps, ArInnerViewState> {
    private _nextRequestId;
    private _requestMap;
    private nativeRef;
    constructor(props: ArInnerViewProps);
    componentDidMount(): void;
    _onDataReturned(event: ArEvent): void;
    _onError(event: ArErrorEvent): void;
    /**
     * Takes a full screenshot of the rendered camera
     * @returns A promise resolving a base64 encoded image
     */
    takeScreenshot(): Promise<string>;
    /**
     * Reset the model positionning
     * @returns void
     */
    reset(): void;
    /**
     * Loads the model
     * @returns void
     */
    loadModel(): void;
    /**
     * Rotate the model
     * @returns void
     */
    rotate(pitch: number, yaw: number, roll: number): void;
    /**
     * Places the model
     * @returns void
     */
    placeModel(x: number, y: number, z: number): void;
    placeText(x: number, y: number, z: number, color: string, text: string): void;
    /**
     * Returns vector 3 postion from x and y co-ords
     * @returns void
     */
    getPositionVector3(x: number, y: number): Promise<any>;
    createLineAndGetDistance(pos1: PositionVector3, pos2: PositionVector3, color: string): Promise<string>;
    render(): false | React.JSX.Element;
}
export {};
//# sourceMappingURL=index.d.ts.map