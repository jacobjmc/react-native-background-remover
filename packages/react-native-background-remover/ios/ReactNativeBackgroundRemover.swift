import Vision
import CoreImage

public class BackgroundRemoverSwift: NSObject {
    
    @objc
    public func removeBackground(_ imageURI: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        #if targetEnvironment(simulator)
        reject("BackgroundRemover", "SimulatorError", NSError(domain: "BackgroundRemover", code: 2))
        return
        #endif

        if #available(iOS 17.0, *) {
            // iOS 17.0+ - Use enhanced foreground instance mask for general objects
            guard let url = URL(string: imageURI) else {
                reject("BackgroundRemover", "Invalid URL", NSError(domain: "BackgroundRemover", code: 3))
                return
            }
            
            guard let originalImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
                reject("BackgroundRemover", "Unable to load image", NSError(domain: "BackgroundRemover", code: 4))
                return
            }
            
            let imageRequestHandler = VNImageRequestHandler(ciImage: originalImage)
            
            // Use VNGenerateForegroundInstanceMaskRequest for general object segmentation
            let segmentationRequest = VNGenerateForegroundInstanceMaskRequest()
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try imageRequestHandler.perform([segmentationRequest])
                    
                    // Handle multiple instance masks from the new API
                    guard let results = segmentationRequest.results, !results.isEmpty else {
                        reject("BackgroundRemover", "No foreground objects detected in image", NSError(domain: "BackgroundRemover", code: 9))
                        return
                    }
                    
                    // Combine all detected foreground objects into a single mask
                    var combinedMask: CIImage?
                    let context = CIContext()
                    
                    for result in results {
                        do {
                            // Generate mask for all instances in this observation
                            let instanceMaskPixelBuffer = try result.generateMaskedImage(
                                ofInstances: result.allInstances,
                                from: imageRequestHandler,
                                croppedToInstancesExtent: false
                            )
                            
                            let instanceMask = CIImage(cvPixelBuffer: instanceMaskPixelBuffer)
                            
                            if combinedMask == nil {
                                combinedMask = instanceMask
                            } else {
                                // Combine masks using maximum compositing to union all foreground objects
                                combinedMask = combinedMask?.applyingFilter("CIMaximumCompositing", 
                                                                          parameters: [kCIInputBackgroundImageKey: instanceMask])
                            }
                        } catch {
                            // Continue with other instances if one fails
                            continue
                        }
                    }
                    
                    guard let finalMask = combinedMask else {
                        reject("BackgroundRemover", "Failed to generate combined mask", NSError(domain: "BackgroundRemover", code: 8))
                        return
                    }
                    
                    // Ensure mask is properly scaled to match original image
                    var scaledMask = finalMask
                    if finalMask.extent != originalImage.extent {
                        let scaleX = originalImage.extent.width / finalMask.extent.width
                        let scaleY = originalImage.extent.height / finalMask.extent.height
                        scaledMask = finalMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                    }
                    
                    // Invert the mask since VNGenerateForegroundInstanceMaskRequest returns inverted masks
                    let invertedMask = scaledMask.applyingFilter("CIColorInvert")
                    
                    // Apply the inverted mask to remove background
                    let maskedImage = originalImage.applyingFilter("CIBlendWithMask", parameters: [kCIInputMaskImageKey: invertedMask])
                    
                    // Convert to UIImage via CGImage for better control
                    guard let cgMaskedImage = context.createCGImage(maskedImage, from: maskedImage.extent) else {
                        reject("BackgroundRemover", "Error creating CGImage", NSError(domain: "BackgroundRemover", code: 6))
                        return
                    }
                    
                    let uiImage = UIImage(cgImage: cgMaskedImage)
                    
                    // Save the image as PNG to preserve transparency
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(url.lastPathComponent).appendingPathExtension("png")
                    if let data = uiImage.pngData() {
                        try data.write(to: tempURL)
                        resolve(tempURL.absoluteString)
                    } else {
                        reject("BackgroundRemover", "Error saving image", NSError(domain: "BackgroundRemover", code: 7))
                    }
                    
                } catch {
                    reject("BackgroundRemover", "Error removing background", error)
                }
            }
        } else if #available(iOS 15.0, *) {
            // iOS 15.0-16.x - Fallback to person segmentation for backward compatibility
            guard let url = URL(string: imageURI) else {
                reject("BackgroundRemover", "Invalid URL", NSError(domain: "BackgroundRemover", code: 3))
                return
            }
            
            guard let originalImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
                reject("BackgroundRemover", "Unable to load image", NSError(domain: "BackgroundRemover", code: 4))
                return
            }
            
            let imageRequestHandler = VNImageRequestHandler(ciImage: originalImage)
            
            var segmentationRequest = VNGeneratePersonSegmentationRequest()
            segmentationRequest.qualityLevel = .accurate
            segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try imageRequestHandler.perform([segmentationRequest])
                    guard let pixelBuffer = segmentationRequest.results?.first?.pixelBuffer else {
                        reject("BackgroundRemover", "No people detected in image (iOS 15-16 supports people only)", NSError(domain: "BackgroundRemover", code: 5))
                        return
                    }
                    
                    var maskImage = CIImage(cvPixelBuffer: pixelBuffer)
                    
                    // Adjust mask scaling
                    let scaleX = originalImage.extent.width / maskImage.extent.width
                    let scaleY = originalImage.extent.height / maskImage.extent.height
                    
                    maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                    
                    let maskedImage = originalImage.applyingFilter("CIBlendWithMask", parameters: [kCIInputMaskImageKey: maskImage])
                    
                    // Convert to UIImage via CGImage for better control
                    let context = CIContext()
                    guard let cgMaskedImage = context.createCGImage(maskedImage, from: maskedImage.extent) else {
                        reject("BackgroundRemover", "Error creating CGImage", NSError(domain: "BackgroundRemover", code: 6))
                        return
                    }
                    
                    let uiImage = UIImage(cgImage: cgMaskedImage)
                    
                    // Save the image as PNG to preserve transparency
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(url.lastPathComponent).appendingPathExtension("png")
                    if let data = uiImage.pngData() {
                        try data.write(to: tempURL)
                        resolve(tempURL.absoluteString)
                    } else {
                        reject("BackgroundRemover", "Error saving image", NSError(domain: "BackgroundRemover", code: 7))
                    }
                    
                } catch {
                    reject("BackgroundRemover", "Error removing background", error)
                }
            }
        } else {
            reject("BackgroundRemover", "You need a device with iOS 15 or later", NSError(domain: "BackgroundRemover", code: 1))
        }
    }
}
