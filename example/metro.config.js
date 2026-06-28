// Learn more https://docs.expo.dev/guides/customizing-metro/

const { getDefaultConfig } = require('expo/metro-config')
const path = require('path')

const root = path.resolve(__dirname, '..')
const config = getDefaultConfig(__dirname)

config.projectRoot = __dirname
config.watchFolders = [root]

// Search node_modules in the example first, then the library root.
config.resolver.nodeModulesPaths = [
  path.join(__dirname, 'node_modules'),
  path.join(root, 'node_modules'),
]

// Allow Metro to resolve packages from both locations.
config.resolver.disableHierarchicalLookup = false

config.transformer = {
  ...config.transformer,
  getTransformOptions: async () => ({
    transform: {
      experimentalImportSupport: false,
      inlineRequires: true,
    },
  }),
}

module.exports = config