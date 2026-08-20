const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Le modele 3D est un binaire : Metro doit le traiter comme un asset a copier,
// pas comme un module JavaScript a transformer.
config.resolver.assetExts.push('glb', 'gltf', 'bin');

module.exports = config;
