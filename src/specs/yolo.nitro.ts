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

export interface Yolo extends HybridObject<{
  ios: 'swift'
  android: 'kotlin'
}> {
  sum(num1: number, num2: number): number
  loadModel(modelPath: string): void
  frameToBase64(frame: Frame): string
  detect(frame: Frame): Detection[]
}
