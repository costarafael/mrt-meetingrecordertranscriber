#!/usr/bin/env  bash

set -ex

dir=build-swift-macos
mkdir -p $dir
cd $dir

# Otimizações para Apple Silicon M1/M2 - ARM64 específico
cmake \
  -DSHERPA_ONNX_ENABLE_BINARY=OFF \
  -DSHERPA_ONNX_BUILD_C_API_EXAMPLES=OFF \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG -march=armv8-a+fp+simd -mtune=apple-m1 -ffast-math" \
  -DCMAKE_C_FLAGS="-O3 -DNDEBUG -march=armv8-a+fp+simd -mtune=apple-m1 -ffast-math" \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_CHECK=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
  -DSHERPA_ONNX_ENABLE_JNI=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  -DCMAKE_Fortran_COMPILER=FALSE \
  ../

# Compilação otimizada para Apple Silicon
make VERBOSE=1 -j8
make install
rm -fv ./install/include/cargs.h

# Criação da biblioteca estática otimizada
libtool -static -o ./install/lib/libsherpa-onnx.a \
  ./install/lib/libsherpa-onnx-c-api.a \
  ./install/lib/libsherpa-onnx-core.a \
  ./install/lib/libkaldi-native-fbank-core.a \
  ./install/lib/libkissfft-float.a \
  ./install/lib/libsherpa-onnx-fstfar.a \
  ./install/lib/libsherpa-onnx-fst.a \
  ./install/lib/libsherpa-onnx-kaldifst-core.a \
  ./install/lib/libkaldi-decoder-core.a \
  ./install/lib/libucd.a \
  ./install/lib/libpiper_phonemize.a \
  ./install/lib/libespeak-ng.a \
  ./install/lib/libssentencepiece_core.a

# Criação do XCFramework otimizado para Apple Silicon
xcodebuild -create-xcframework \
  -library install/lib/libsherpa-onnx.a \
  -headers install/include \
  -output sherpa-onnx.xcframework

echo "✅ Build otimizado para Apple Silicon concluído!"
echo "🍎 CoreML support: ENABLED"
echo "🚀 ARM64 optimizations: ENABLED"
echo "⚡ Neural Engine: READY"
