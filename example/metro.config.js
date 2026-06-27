const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');

const root = path.resolve(__dirname, '..');
const defaultConfig = getDefaultConfig(__dirname);

const config = {
  watchFolders: [root],
  resolver: {
    assetExts: [
      ...defaultConfig.resolver.assetExts,
      'tflite',
      'onnx',
      'nb',
      'txt',
    ],
  },
};

module.exports = mergeConfig(defaultConfig, config);

