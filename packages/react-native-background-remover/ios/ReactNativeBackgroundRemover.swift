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
                    
                    // Combine all detected foreground objects into a single image
                    var combinedImage: CIImage?
                    let context = CIContext()

                    for result in results {
                        do {
                            // Generate a masked image for all instances in this observation.
                            // This returns a pre-masked image with a transparent background.
                            let instanceMaskPixelBuffer = try result.generateMaskedImage(
                                ofInstances: result.allInstances,
                                from: imageRequestHandler,
                                croppedToInstancesExtent: false
                            )
                            
                            let instanceImage = CIImage(cvPixelBuffer: instanceMaskPixelBuffer)
                            
                            if combinedImage == nil {
                                combinedImage = instanceImage
                            } else {
                                // Composite the new instance image over the existing combined image.
                                combinedImage = instanceImage.applyingFilter("CISourceOverCompositing",
                                                                          parameters: [kCIInputBackgroundImageKey: combinedImage!])
                            }
                        } catch {
                            // Continue with other instances if one fails
                            continue
                        }
                    }
                    
                    guard var maskedImage = combinedImage else {
                        reject("BackgroundRemover", "Failed to generate combined image", NSError(domain: "BackgroundRemover", code: 8))
                        return
                    }
                    
                    // The output of generateMaskedImage is already at the correct scale of the original image.
                    // No scaling should be needed if croppedToInstancesExtent is false.
                    if maskedImage.extent != originalImage.extent {
                        let scaleX = originalImage.extent.width / maskedImage.extent.width
                        let scaleY = originalImage.extent.height / maskedImage.extent.height
                        maskedImage = maskedImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                    }
                    
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
