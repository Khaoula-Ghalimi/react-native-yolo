import { NitroModules } from 'react-native-nitro-modules'
import type { Yolo as YoloSpec } from './specs/yolo.nitro'
import { Image } from 'react-native'
import type { Frame } from 'react-native-vision-camera';

const NativeYolo = NitroModules.createHybridObject<YoloSpec>('Yolo')

export const Yolo = {
  loadModel(modelAssetId: number) {
    const { uri } = Image.resolveAssetSource(modelAssetId)
    return NativeYolo.loadModel(uri)
  },

  frameToBase64(frame: Frame) {
    return NativeYolo.frameToBase64(frame)
  },
}
export type {
  Detection,
  BoundingBox,
  YoloModel,
} from './specs/yolo.nitro'
