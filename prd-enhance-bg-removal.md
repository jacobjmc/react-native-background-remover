# PRD: General Purpose Background Remover Package Enhancement

## Overview

Enhance the `react-native-background-remover` package to support general object background removal (not just people) by migrating from Apple's `VNGeneratePersonSegmentationRequest` to `VNGenerateForegroundInstanceMaskRequest` Vision API. This will enable background removal for cars, furniture, animals, and any foreground objects while maintaining backward compatibility with people-focused use cases.

## Problem Statement

### Current Limitations
- **People-Only Focus**: Current implementation uses `VNGeneratePersonSegmentationRequest` which only works well on images containing people
- **Poor Object Results**: Background removal fails or produces poor results on cars, furniture, animals, and other objects
- **Limited Use Cases**: Restricts the package's applicability to portrait/people photography only

### Business Impact
- **Reduced Adoption**: Developers avoid the package for general-purpose background removal
- **Competitive Disadvantage**: Other solutions support general object segmentation
- **User Frustration**: Poor results when users try to remove backgrounds from non-people images

## Solution Overview

### Technical Approach
Migrate from person-specific to general-purpose Vision API while maintaining the same React Native interface and improving overall functionality.

### Key Benefits
- ✅ **Universal Compatibility**: Works on people AND objects
- ✅ **Backward Compatible**: Existing people-focused apps continue working
- ✅ **Better Quality**: More accurate segmentation for diverse subjects
- ✅ **Same Performance**: Similar processing times and resource usage
- ✅ **iOS 15+ Support**: Maintains current iOS version requirements

## Requirements

### 1. **Functional Requirements**

#### **Core Functionality**
- **FR-1**: Remove backgrounds from images containing people (maintain existing capability)
- **FR-2**: Remove backgrounds from images containing objects (cars, furniture, animals, etc.)
- **FR-3**: Handle images with multiple foreground subjects (people + objects)
- **FR-4**: Maintain same React Native API interface (`removeBackground(imageURI)`)
- **FR-5**: Return processed image with transparent background in PNG format

#### **Quality Requirements**
- **FR-6**: Achieve visually comparable or better results than current implementation for people
- **FR-7**: Produce high-quality results for common objects (cars, furniture, pets)
- **FR-8**: Handle edge detection and fine details (hair, fur, complex edges)

#### **Error Handling**
- **FR-9**: Gracefully handle images with no detectable foreground objects
- **FR-10**: Provide meaningful error messages for different failure scenarios
- **FR-11**: Maintain app stability (no crashes on edge cases)

### 2. **Technical Requirements**

#### **iOS Implementation**
- **TR-1**: Replace `VNGeneratePersonSegmentationRequest` with `VNGenerateForegroundInstanceMaskRequest`
- **TR-2**: Handle multiple instance masks and combine them appropriately
- **TR-3**: Maintain iOS 15.0+ compatibility requirement
- **TR-4**: Preserve existing Swift/Objective-C bridge architecture

#### **Performance Requirements**
- **TR-5**: Processing time ≤ 5 seconds for typical images (same as current)
- **TR-6**: Memory usage within reasonable bounds for mobile devices
- **TR-7**: Support images up to 4K resolution

#### **Compatibility Requirements**
- **TR-8**: Maintain exact same TypeScript interface
- **TR-9**: No breaking changes to existing React Native integration
- **TR-10**: Support both new and old React Native architectures

### 3. **Testing Requirements**

#### **Device Testing**
- **TT-1**: Test on real iOS devices (iOS 15+, including iOS 18.5)
- **TT-2**: Verify simulator detection and appropriate error handling
- **TT-3**: Test on various device models and screen sizes

#### **Image Testing Categories**
- **TT-4**: **People Images**: Single person, multiple people, people with objects
- **TT-5**: **Object Images**: Cars, furniture, animals, food, electronics
- **TT-6**: **Mixed Scenes**: People and objects together
- **TT-7**: **Edge Cases**: No clear subjects, low contrast, small objects

## Technical Implementation

### 1. **Vision API Migration**

#### **Current Implementation (ReactNativeBackgroundRemover.swift:26)**
```swift
var segmentationRequest = VNGeneratePersonSegmentationRequest()
segmentationRequest.qualityLevel = .accurate
segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
```

#### **New Implementation**
```swift
var segmentationRequest = VNGenerateForegroundInstanceMaskRequest()
segmentationRequest.qualityLevel = .accurate
// Note: outputPixelFormat handled internally by new API
```

### 2. **Multiple Instance Handling**

#### **Challenge**
`VNGenerateForegroundInstanceMaskRequest` returns multiple instance masks (one per detected object) vs. single mask from person segmentation.

#### **Solution: Union Strategy**
```swift
// Combine all detected foreground objects into single mask
guard let results = segmentationRequest.results as? [VNInstanceMaskObservation], !results.isEmpty else {
    reject("BackgroundRemover", "No foreground objects detected", NSError(domain: "BackgroundRemover", code: 9))
    return
}

var combinedMask: CIImage?
for result in results {
    guard let instanceMask = try? result.generateMaskedImage(
        ofInstances: result.allInstances, 
        from: imageRequestHandler, 
        croppedToInstancesExtent: false
    ) else { continue }
    
    if combinedMask == nil {
        combinedMask = instanceMask
    } else {
        combinedMask = combinedMask?.applyingFilter("CIMaximumCompositing", 
                                                   parameters: [kCIInputBackgroundImageKey: instanceMask])
    }
}
```

### 3. **Enhanced Error Handling**

#### **New Error Codes**
- **Code 8**: Failed to generate combined mask
- **Code 9**: No foreground objects detected in image
- **Code 10**: All instances below confidence threshold

#### **Improved Error Messages**
- Current: "No segmentation results"
- New: "No foreground objects detected in image"
- New: "Failed to combine multiple object masks"

### 4. **File Modifications Required**

#### **Primary Changes**
- **`ios/ReactNativeBackgroundRemover.swift`**: Main Vision API implementation
- **`package.json`**: Update name, version, and description
- **`README.md`**: Update documentation and examples

#### **No Changes Required**
- **`ios/ReactNativeBackgroundRemover.mm`**: Objective-C bridge remains same
- **`ios/ReactNativeBackgroundRemover.h`**: Header file unchanged
- **`src/index.tsx`**: TypeScript interface unchanged
- **`src/NativeBackgroundRemover.ts`**: Native module spec unchanged

## Testing Strategy

### 1. **Development Testing Environment**

#### **Local Testing Setup**
- **Location**: `/Users/jacob/Documents/code/react-native-background-remover/apps/expo`
- **Method**: Direct local package testing via babel module resolver
- **Device**: iOS device with iOS 18.5
- **Workflow**: Edit Swift → Rebuild → Test immediately

#### **Testing Commands**
```bash
cd /Users/jacob/Documents/code/react-native-background-remover/apps/expo

# Clear cache and run on device
npx expo start --clear
npx expo run:ios --device
```

### 2. **Test Image Categories**

#### **Category 1: People Images (Backward Compatibility)**
- **Single Person**: Portrait photos, full body shots
- **Multiple People**: Group photos, family pictures
- **People + Objects**: Person with car, person with pet
- **Expected Result**: Same or better quality than current implementation

#### **Category 2: Object Images (New Capability)**
- **Vehicles**: Cars, motorcycles, bicycles
- **Animals**: Dogs, cats, birds, wildlife
- **Furniture**: Chairs, tables, lamps
- **Electronics**: Phones, laptops, appliances
- **Expected Result**: Clean background removal with preserved object details

#### **Category 3: Mixed Scenes**
- **People + Pets**: Person holding dog/cat
- **People + Vehicles**: Person standing next to car
- **Multiple Objects**: Car and person in same scene
- **Expected Result**: All foreground subjects preserved

#### **Category 4: Edge Cases**
- **No Clear Subject**: Landscape photos, abstract images
- **Low Contrast**: Subject blends with background
- **Small Objects**: Distant subjects, tiny details
- **Complex Backgrounds**: Busy scenes, similar colors
- **Expected Result**: Graceful failure with helpful error messages

### 3. **Performance Testing**

#### **Metrics to Measure**
- **Processing Time**: Target ≤ 5 seconds per image
- **Memory Usage**: Monitor peak memory during processing
- **Success Rate**: Percentage of images processed successfully
- **Quality Score**: Subjective quality assessment (1-10 scale)

#### **Test Image Specifications**
- **Resolution Range**: 1080p to 4K
- **File Formats**: JPEG, PNG, HEIC
- **File Sizes**: 1MB to 10MB
- **Aspect Ratios**: Square, portrait, landscape

### 4. **Comparative Testing**

#### **Before vs After Comparison**
- **Same Test Images**: Use identical image set for both versions
- **Quality Assessment**: Side-by-side visual comparison
- **Performance Metrics**: Processing time and success rate comparison
- **Use Case Coverage**: Document which use cases improve vs. remain same

#### **Success Criteria**
- **People Images**: ≥95% maintain or improve quality
- **Object Images**: ≥80% produce acceptable results (vs. current poor results)
- **Processing Time**: ≤110% of current processing time
- **Crash Rate**: 0% crashes on test image set

## Implementation Plan

### **Phase 1: Core Implementation** (Priority: High)
1. **Modify Vision API**: Replace person segmentation with foreground instance mask
2. **Implement Mask Combination**: Handle multiple instance results
3. **Update Error Handling**: Add new error codes and messages
4. **Basic Testing**: Verify functionality with sample images

### **Phase 2: Testing & Refinement** (Priority: High)
1. **Comprehensive Testing**: Test all image categories on real device
2. **Performance Optimization**: Fine-tune mask combination algorithm
3. **Edge Case Handling**: Improve error scenarios and fallbacks
4. **Quality Assessment**: Compare results with current implementation

### **Phase 3: Documentation & Publishing** (Priority: Medium)
1. **Update Documentation**: README, examples, API docs
2. **Package Preparation**: Update package.json, version, description
3. **Fork Repository**: Create fork with descriptive name
4. **Publish Package**: Release to npm with new name

### **Phase 4: Integration** (Priority: Low)
1. **Update Main App**: Switch to new package in production app
2. **Monitor Performance**: Track real-world usage and performance
3. **Community Feedback**: Gather feedback and iterate
4. **Maintenance**: Bug fixes and improvements

## Success Metrics

### **Technical Metrics**
- **API Migration**: Successfully replace Vision API without breaking changes
- **Backward Compatibility**: 100% of existing people-focused functionality preserved
- **New Capability**: ≥80% success rate on object background removal
- **Performance**: Processing time within 110% of current implementation

### **Quality Metrics**
- **People Images**: ≥95% maintain or improve visual quality
- **Object Images**: ≥80% produce usable results (vs. current poor results)
- **Edge Cases**: Graceful handling with helpful error messages
- **Stability**: 0% crash rate on comprehensive test suite

### **Business Metrics**
- **Package Adoption**: Increased downloads and usage
- **Developer Satisfaction**: Positive feedback on expanded capabilities
- **Use Case Expansion**: Package used for broader range of applications
- **Community Contribution**: Potential for community contributions and improvements

## Risk Assessment & Mitigation

### **Technical Risks**
- **Risk**: Multiple instance handling complexity
  - **Mitigation**: Implement robust mask combination with fallbacks
- **Risk**: Performance degradation with multiple objects
  - **Mitigation**: Optimize algorithm and set reasonable limits
- **Risk**: Quality regression for people images
  - **Mitigation**: Extensive comparative testing and fine-tuning

### **Compatibility Risks**
- **Risk**: Breaking changes to existing apps
  - **Mitigation**: Maintain exact same API interface
- **Risk**: iOS version compatibility issues
  - **Mitigation**: Thorough testing on iOS 15+ devices
- **Risk**: React Native architecture compatibility
  - **Mitigation**: Test both old and new RN architectures

### **Business Risks**
- **Risk**: Community adoption of fork vs. original
  - **Mitigation**: Clear documentation of improvements and benefits
- **Risk**: Maintenance burden of forked package
  - **Mitigation**: Plan for ongoing maintenance and community contributions

## Deliverables

### **Code Deliverables**
1. **Modified Package**: Enhanced `react-native-background-remover` with general object support
2. **Test Suite**: Comprehensive test images and validation scripts
3. **Documentation**: Updated README, API docs, and usage examples
4. **Published Package**: npm package with new name and capabilities

### **Documentation Deliverables**
1. **Technical Documentation**: Implementation details and architecture decisions
2. **Migration Guide**: How to upgrade from original package
3. **Performance Report**: Comparative analysis of before/after performance
4. **Test Results**: Comprehensive testing results and quality assessment

### **Process Deliverables**
1. **Testing Methodology**: Reusable testing process for future enhancements
2. **Development Workflow**: Local testing setup and iteration process
3. **Publishing Process**: Fork, modify, test, publish workflow
4. **Maintenance Plan**: Ongoing support and improvement strategy

## Timeline

### **Week 1: Implementation**
- Day 1-2: Vision API migration and core implementation
- Day 3-4: Multiple instance handling and mask combination
- Day 5-7: Error handling and edge case management

### **Week 2: Testing**
- Day 1-3: Comprehensive device testing with all image categories
- Day 4-5: Performance testing and optimization
- Day 6-7: Quality assessment and comparative analysis

### **Week 3: Publishing**
- Day 1-2: Documentation updates and package preparation
- Day 3-4: Fork repository and publish to npm
- Day 5-7: Integration testing and final validation

This PRD provides a comprehensive roadmap for enhancing the background remover package to support general object segmentation while maintaining backward compatibility and ensuring high quality results across diverse use cases.

[Tool: todowrite]

I've created a comprehensive PRD that covers all aspects of the background remover package enhancement project. The document should be saved as `prd-general-background-remover-enhancement.md` and includes:

## Key Sections Covered:

1. **Problem Statement & Solution Overview** - Clear business case for the changes
2. **Detailed Requirements** - Functional, technical, and testing requirements
3. **Technical Implementation** - Specific code changes and Vision API migration
4. **Comprehensive Testing Strategy** - Using the expo app for local testing
5. **Implementation Plan** - Phased approach with priorities
6. **Success Metrics** - Measurable criteria for success
7. **Risk Assessment** - Potential issues and mitigation strategies
8. **Timeline** - 3-week implementation schedule

## Highlights:

- **Local Testing Workflow**: Detailed plan for using `/apps/expo` for immediate testing
- **Vision API Migration**: Specific Swift code changes from person to general object segmentation
- **Backward Compatibility**: Ensures existing people-focused functionality is preserved
- **Comprehensive Test Categories**: People, objects, mixed scenes, and edge cases
- **Performance Targets**: Specific metrics for success (≤5 seconds processing, ≥80% success rate)
- **Publishing Strategy**: Fork → Modify → Test → Publish workflow

The PRD provides a complete roadmap for transforming the package from people-only to general-purpose background removal while maintaining quality and compatibility.