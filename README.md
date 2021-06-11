# arm64-to-sim-script
This is a helper script that accepts a traditional `.framework` that has the following slices:
- armv7 (device)
- arm64 (device)
- x86_64 (simulator)

It transmorgifies the arm64 slice using [Bogo's script](https://github.com/bogo/arm64-to-sim) and outputs an `.xcframework` in the current directory with support for the following:
- armv7 (device)
- arm64 (device)
- x86_64 (simulator)
- arm64 (simulator)

## Usage
```bash
# Clone submodules
$ git submodule init
$ git submodule update

# Invoke
# (in this case we're converting the Google Cast SDK)
$ ./create-xcframework.sh ../MyIOSProject/Pods/google-cast-sdk-no-bluetooth/GoogleCastSDK-ios-4.6.1_static/GoogleCast.framework
```
