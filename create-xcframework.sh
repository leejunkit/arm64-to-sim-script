#!/bin/bash
set -e

get_abs_filename() {
    # $1 : relative filename
    echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

BOGO_REALPATH=$(get_abs_filename ./arm64-to-sim/Sources/arm64-to-sim/main.swift)
PATH_TO_STATIC_FRAMEWORK=$(get_abs_filename $1)
CURRENT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)

echo "Using temporary directory $TEMP_DIR"
echo "Using input .framework: $PATH_TO_STATIC_FRAMEWORK"

## Get the filename of the library
FILENAME=$(basename -- "$PATH_TO_STATIC_FRAMEWORK")
FILENAME="${FILENAME%.*}"

## Extract the slices
lipo -thin arm64 $PATH_TO_STATIC_FRAMEWORK/$FILENAME -output $TEMP_DIR/$FILENAME.arm64
lipo -thin armv7 $PATH_TO_STATIC_FRAMEWORK/$FILENAME -output $TEMP_DIR/$FILENAME.armv7
lipo -thin x86_64 $PATH_TO_STATIC_FRAMEWORK/$FILENAME -output $TEMP_DIR/$FILENAME.x86_64-simulator

## Extract the arm64 slice again; we're going to transmorgify this for arm64 simulator
mkdir $TEMP_DIR/arm64-simulator
lipo -thin arm64 $PATH_TO_STATIC_FRAMEWORK/$FILENAME -output $TEMP_DIR/arm64-simulator/$FILENAME

## Unarchive arm64-simulator
cd $TEMP_DIR/arm64-simulator
ar x $FILENAME

## Transmorgify arm64 framework for arm64 simulator
for file in *.o
do
    echo "Transmorgifying $file"
    swift $BOGO_REALPATH $file
done

## Archive transmorgified .o files into a library again
ar crv ../$FILENAME.arm64-simulator *.o

## Move back to the temp directory root
cd ..

## Create two fat binaries, one for simulator and one for device
lipo -create -output $TEMP_DIR/$FILENAME.device $TEMP_DIR/$FILENAME.arm64 $TEMP_DIR/$FILENAME.armv7
lipo -create -output $TEMP_DIR/$FILENAME.simulator $TEMP_DIR/$FILENAME.arm64-simulator $TEMP_DIR/$FILENAME.x86_64-simulator

## We now need to reconstruct the frameworks
TEMP_FRAMEWORK_PATH=$TEMP_DIR/Frameworks
mkdir -p $TEMP_FRAMEWORK_PATH/$FILENAME-Device/$FILENAME.framework
mkdir -p $TEMP_FRAMEWORK_PATH/$FILENAME-Simulator/$FILENAME.framework
cp -a $PATH_TO_STATIC_FRAMEWORK/ $TEMP_FRAMEWORK_PATH/$FILENAME-Device/$FILENAME.framework
cp -a $PATH_TO_STATIC_FRAMEWORK/ $TEMP_FRAMEWORK_PATH/$FILENAME-Simulator/$FILENAME.framework

## Remove the original binaries
rm $TEMP_FRAMEWORK_PATH/$FILENAME-Device/$FILENAME.framework/$FILENAME
rm $TEMP_FRAMEWORK_PATH/$FILENAME-Simulator/$FILENAME.framework/$FILENAME

## Copy the new binaries into the frameworks
cp $TEMP_DIR/$FILENAME.device $TEMP_FRAMEWORK_PATH/$FILENAME-Device/$FILENAME.framework/$FILENAME
cp $TEMP_DIR/$FILENAME.simulator $TEMP_FRAMEWORK_PATH/$FILENAME-Simulator/$FILENAME.framework/$FILENAME

## Finally, invoke xcodebuild to create an xcframework
rm -rf $CURRENT_DIR/$FILENAME.xcframework || true
xcodebuild -create-xcframework \
    -framework $TEMP_FRAMEWORK_PATH/$FILENAME-Device/$FILENAME.framework \
    -framework $TEMP_FRAMEWORK_PATH/$FILENAME-Simulator/$FILENAME.framework \
    -output $CURRENT_DIR/$FILENAME.xcframework

## Cleanup
rm -rf $TEMP_DIR
