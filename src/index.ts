import { NitroModules } from 'react-native-nitro-modules'
import type { Yolo as YoloSpec } from './specs/yolo.nitro'

export const Yolo =
  NitroModules.createHybridObject<YoloSpec>('Yolo')