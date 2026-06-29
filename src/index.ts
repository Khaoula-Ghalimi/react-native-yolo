import { NitroModules } from 'react-native-nitro-modules'
import type { Yolo as YoloSpec } from './specs/yolo.nitro'
import { Image } from 'react-native'

const NativeYolo = NitroModules.createHybridObject<YoloSpec>('Yolo')


export const Yolo = {
  ...NativeYolo,

  loadModel(modelAssetId: number) {
    const { uri } = Image.resolveAssetSource(modelAssetId)
    return NativeYolo.loadModel(uri)
  },
}
export type {
  Detection,
  BoundingBox,
  YoloModel,
} from './specs/yolo.nitro'
