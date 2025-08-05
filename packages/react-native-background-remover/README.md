# react-native-background-remover

Enhanced React Native package that uses MLKit on Android and Apple's Vision framework on iOS to remove backgrounds from images containing people, objects, animals, and more.

<div align="center">
  <video src="https://github.com/user-attachments/assets/ce62728f-69fb-46d2-8016-7d03f751708e" width="400" />
</div>

## Installation

```sh
yarn add react-native-background-remover
```

## Usage

```js
import { removeBackground } from 'react-native-background-remover';

// You can get the imageURI from the camera or the gallery.
const backgroundRemovedImageURI = removeBackground(imageURI);
```

## Features

### ✨ **Enhanced Object Support**

- **iOS 17.0+**: Remove backgrounds from **any foreground objects** including:

  - 👥 **People** (single or multiple)
  - 🚗 **Vehicles** (cars, motorcycles, bicycles)
  - 🐕 **Animals** (pets, wildlife)
  - 🪑 **Furniture** (chairs, tables, lamps)
  - 📱 **Electronics** (phones, laptops, appliances)
  - 🍎 **Food items** and other objects

- **iOS 15.0-16.x**: **People-only** background removal (maintains original functionality)

### 🔄 **Backward Compatibility**

- Same API interface - no code changes required
- Automatic iOS version detection and appropriate API selection
- Graceful fallback for older iOS versions

### 🎯 **Smart Detection**

- Combines multiple detected objects into a single result
- Handles complex scenes with people and objects together
- High-quality edge detection for fine details (hair, fur, complex edges)

## Platform Support

> **iOS**: You need to use a real device on iOS to use this package. Otherwise, it will throw a warning and return the original image. You can still use an emulator on Android.

> **iOS Version Requirements**:
>
> - **iOS 17.0+**: Full object segmentation (people, cars, animals, furniture, etc.)
> - **iOS 15.0-16.x**: People-only segmentation
> - **iOS 14.x and below**: Not supported

> **Android**: Uses MLKit for background removal (emulator supported)

## Error Handling

The package provides detailed error messages for different scenarios:

```js
try {
  const result = await removeBackground(imageURI);
  // Success - result contains the processed image URI
} catch (error) {
  console.log(error.code, error.message);
  // Error codes:
  // 1: iOS version too old (< iOS 15)
  // 2: Running on iOS simulator (not supported)
  // 3: Invalid image URI
  // 4: Unable to load image
  // 5: No people detected (iOS 15-16 only)
  // 6: Error creating final image
  // 7: Error saving processed image
  // 8: Failed to generate combined mask (iOS 17+)
  // 9: No foreground objects detected (iOS 17+)
}
```

## Technical Details

### iOS Implementation

- **iOS 17.0+**: Uses `VNGenerateForegroundInstanceMaskRequest` for general object segmentation
- **iOS 15.0-16.x**: Uses `VNGeneratePersonSegmentationRequest` for people-only segmentation
- **Output**: PNG format with transparency preservation
- **Processing**: Combines multiple detected objects into unified mask

### Android Implementation

- Uses MLKit for background removal
- Supports both emulator and real devices

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
