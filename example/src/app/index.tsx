import { useEffect, useState, useCallback, useRef } from 'react'
import {
  StyleSheet,
  Text,
  View,
  Image,
  useWindowDimensions,
} from 'react-native'
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameOutput,
} from 'react-native-vision-camera'
import { Yolo } from 'react-native-yolo'
import type { Detection, YoloModel } from 'react-native-yolo'
import { runOnJS } from 'react-native-worklets'

const MODEL_SIZE = 640

export default function HomeScreen() {
  const device = useCameraDevice('back')
  const { hasPermission, requestPermission } = useCameraPermission()
  const { width: screenW, height: screenH } = useWindowDimensions()
  const modelRef = useRef<YoloModel | null>(null)

  useEffect(() => {
    modelRef.current = Yolo.loadModel(require('@/assets/models/yolo.tflite'))

    return () => {
      modelRef.current?.close()
      modelRef.current = null
    }
  }, [])

  const [detections, setDetections] = useState<Detection[]>([])
  const [previewUri, setPreviewUri] = useState<string | null>(null)
  const [isActive, setIsActive] = useState(true)

  const mountedRef = useRef(true)
  const lastUpdateRef = useRef(0)

  const updatePreview = useCallback((b64String: string) => {
    if (!mountedRef.current || !b64String) return
    setPreviewUri(`data:image/jpeg;base64,${b64String}`)
  }, [])
  const processFrameOnJS = useCallback((frame: any) => {
    const b64 = Yolo.frameToBase64(frame)
    updatePreview(b64)
  }, [updatePreview])

  const updateDetections = useCallback((next: Detection[]) => {
    if (!mountedRef.current) return
    console.log('detections', next)
    setDetections(next)
  }, [])

  const frameOutput = useFrameOutput({
    pixelFormat: 'yuv',
    dropFramesWhileBusy: true,
    onFrame(frame) {
      'worklet'

      // const now = Date.now()

      // if (now - lastUpdateRef.current > 300) {
      //   lastUpdateRef.current = now

      //   const b64 = Yolo.frameToBase64(frame)
      //   const nextDetections = Yolo.detect(frame)

      //   if (b64.length > 0) {
      //     runOnJS(updatePreview)(b64)
      //   }
      // }

      const now = Date.now()

      if (now - lastUpdateRef.current > 300) {
        lastUpdateRef.current = now

        runOnJS(processFrameOnJS)(frame)

        const model = modelRef.current

        if (model != null) {
          const nextDetections = model.detect(frame)
          runOnJS(updateDetections)(nextDetections)
        }
      }

      frame.dispose()
    },
  })

  useEffect(() => {
    mountedRef.current = true
    setIsActive(true)

    return () => {
      mountedRef.current = false
      setIsActive(false)
      setPreviewUri(null)
      setDetections([])
    }
  }, [])

  useEffect(() => {
    if (!hasPermission) requestPermission()
  }, [hasPermission, requestPermission])

  if (!hasPermission) {
    return (
      <View style={styles.center}>
        <Text>No camera permission</Text>
      </View>
    )
  }

  if (device == null) {
    return (
      <View style={styles.center}>
        <Text>No camera device found</Text>
      </View>
    )
  }

  return (
    <View style={styles.container}>
      <Camera
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={isActive}
        outputs={isActive ? [frameOutput] : []}
        orientationSource="device"
      />

      <View pointerEvents="none" style={[StyleSheet.absoluteFill]}>
        {detections.map((d, index) => {
          const box = d.boundingBox

          const x1 = Math.max(0, box.x1) * screenW
          const y1 = Math.max(0, box.y1) * screenH
          const x2 = Math.min(1, box.x2) * screenW
          const y2 = Math.min(1, box.y2) * screenH

          return (
            <View
              key={index}
              style={[
                styles.box,
                {
                  left: x1,
                  top: y1,
                  width: Math.max(1, x2 - x1),
                  height: Math.max(1, y2 - y1),
                },
              ]}
            >
              <Text style={styles.boxText}>
                {d.classId} {Math.round(d.score * 100)}%
              </Text>
            </View>
          )
        })}
      </View>

      <View style={styles.previewContainer}>
        <Text style={styles.previewText}>
          YOLO Frame Orientation Preview: {detections.length}
        </Text>

        {previewUri ? (
          <Image source={{ uri: previewUri }} style={styles.previewImage} />
        ) : (
          <View style={[styles.previewImage, styles.placeholder]}>
            <Text style={styles.placeholderText}>Waiting for frame...</Text>
          </View>
        )}
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'black',
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  previewContainer: {
    position: 'absolute',
    bottom: 40,
    alignSelf: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.75)',
    padding: 10,
    borderRadius: 12,
    alignItems: 'center',
    zIndex: 1000,
    elevation: 1000,
  },
  previewText: {
    color: 'white',
    fontSize: 12,
    marginBottom: 6,
    fontWeight: 'bold',
  },
  previewImage: {
    width: 160,
    height: 120,
    borderRadius: 8,
    backgroundColor: '#222',
    resizeMode: 'contain',
  },
  placeholder: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderText: {
    color: '#666',
    fontSize: 10,
  },
  box: {
    position: 'absolute',
    borderWidth: 4,
    borderColor: 'lime',
    backgroundColor: 'rgba(0,255,0,0.1)',
    zIndex: 999,
    elevation: 999,
  },
  boxText: {
    position: 'absolute',
    top: -22,
    left: 0,
    color: 'black',
    backgroundColor: 'lime',
    fontSize: 12,
    fontWeight: 'bold',
    paddingHorizontal: 4,
  },
})
