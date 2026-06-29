import type { HybridObject } from 'react-native-nitro-modules'
import type { Frame } from 'react-native-vision-camera'

export type Detection = {
  classId: number
  score: number
  boundingBox: BoundingBox
}
export type BoundingBox = {
  x1: number
  y1: number
  x2: number
  y2: number
}

export interface YoloModel extends HybridObject<{
  ios: 'swift'
  android: 'kotlin'
}> {
  detect(frame: Frame): Detection[]
  close(): void

}

export interface Yolo extends HybridObject<{
  ios: 'swift'
  android: 'kotlin'
}> {
  loadModel(modelPath: string): YoloModel
  frameToBase64(frame: Frame): string
}


