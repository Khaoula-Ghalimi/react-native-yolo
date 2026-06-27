import React, { useEffect } from 'react';
import { Text, View, StyleSheet, Image } from 'react-native';
import { Yolo } from 'react-native-yolo';

function App(): React.JSX.Element {
  useEffect(() => {
    const assetId = require('./assets/models/yolo11n_float32.tflite');
    Yolo.loadModelTest(assetId);
  }, []);

  const keys = [
    ...Object.getOwnPropertyNames(Yolo),
    ...Object.getOwnPropertyNames(Object.getPrototypeOf(Yolo)),
  ];

  return (
    <View style={styles.container}>
      {/* <Text>
        {' '}
        {JSON.stringify(Image.resolveAssetSource(assetId), null, 2)}{' '}
      </Text> */}
      {/* <Text>
        {' '}
        {JSON.stringify(Yolo.loadModelTest(assetId), null, 2)}{' '}
      </Text>  */}
      <Text>
        {' '}
        {keys.map(k => `${k}: ${typeof (Yolo as any)[k]}`).join('\n')}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  text: {
    fontSize: 40,
    color: 'green',
  },
});

export default App;
