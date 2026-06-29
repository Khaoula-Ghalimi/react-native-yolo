import { useEffect, useState, useCallback, useRef } from 'react'
import { StyleSheet, Text, View, Image } from 'react-native'
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameOutput,
  
} from 'react-native-vision-camera'
import { Yolo } from 'react-native-yolo'
import { runOnJS } from 'react-native-worklets'

export default function HomeScreen() {
  const device = useCameraDevice('back')
  const { hasPermission, requestPermission } = useCameraPermission()

  const [previewUri, setPreviewUri] = useState<string | null>(null)
  const [isActive, setIsActive] = useState(true)

  const mountedRef = useRef(true)
  const lastUpdateRef = useRef(0)

  const updatePreview = useCallback((b64String: string) => {
    if (!mountedRef.current) return
    if (!b64String) return

    setPreviewUri(`data:image/jpeg;base64,${b64String}`)
  }, [])

  const frameOutput = useFrameOutput({
    pixelFormat: 'yuv',
    dropFramesWhileBusy: true,
    onFrame(frame) {
      'worklet'

      const now = Date.now()

      if (now - lastUpdateRef.current > 300) {
        lastUpdateRef.current = now

        const b64 = Yolo.frameToBase64(frame)

        if (b64.length > 0) {
          runOnJS(updatePreview)(b64)
        }
      }

      frame.dispose()
    },
  })

  useEffect(() => {
    mountedRef.current = true
    setIsActive(true)

    return () => {
      console.log('left')
      mountedRef.current = false
      setIsActive(false)
      setPreviewUri(null)
    }
  }, [])

  useEffect(() => {
    if (!hasPermission) {
      requestPermission()
    }
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

      <View style={styles.previewContainer}>
        <Text style={styles.previewText}>YOLO Frame Orientation Preview:</Text>

        {previewUri ? (
          <Image
            source={{ uri: previewUri }}
            style={styles.previewImage}
          />
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
})
