/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates converting vImage buffers to and from CVPixelBuffer objects.
*/

import UIKit
import CoreImage
import Accelerate.vImage

class ViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        applyFilter()
    }
    
    func applyFilter() {
        let image = #imageLiteral(resourceName: "Flowers_2.jpg")
        
        if let ciImage = CIImage(image: image),
            let result = try? EqualizationImageProcessorKernel.apply(
                withExtent: ciImage.extent,
                inputs: [ciImage],
                arguments: nil) {
            imageView.image = UIImage(ciImage: result)
        }
    }
}

class EqualizationImageProcessorKernel: CIImageProcessorKernel {
    
    enum EqualizationImageProcessorError: Error {
        case equalizationOperationFailed
    }
    
    static var format = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)
    
    override class var outputFormat: CIFormat {
        return kCIFormatBGRA8
    }
    
    override class func formatForInput(at input: Int32) -> CIFormat {
        return kCIFormatBGRA8
    }
    
    override class func process(with inputs: [CIImageProcessorInput]?,
                                arguments: [String : Any]?,
                                output: CIImageProcessorOutput) throws {
        
        guard
            let input = inputs?.first,
            let inputPixelBuffer = input.pixelBuffer,
            let outputPixelBuffer = output.pixelBuffer else {
                return
        }
        
        var sourceBuffer = vImage_Buffer()
        
        let inputCVImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(inputPixelBuffer).takeRetainedValue()
        vImageCVImageFormat_SetColorSpace(inputCVImageFormat,
                                          CGColorSpaceCreateDeviceRGB())
        
        var error = kvImageNoError
        
        error = vImageBuffer_InitWithCVPixelBuffer(&sourceBuffer,
                                                   &format,
                                                   inputPixelBuffer,
                                                   inputCVImageFormat,
                                                   nil,
                                                   vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            throw EqualizationImageProcessorError.equalizationOperationFailed
        }
        defer {
            free(sourceBuffer.data)
        }
        
        var destinationBuffer = vImage_Buffer()
        
        error = vImageBuffer_Init(&destinationBuffer,
                                  sourceBuffer.height,
                                  sourceBuffer.width,
                                  format.bitsPerPixel,
                                  vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            throw EqualizationImageProcessorError.equalizationOperationFailed
        }
        defer {
            free(destinationBuffer.data)
        }
        
        /*
         All four channel histogram functions (i.e. those that support ARGB8888 or ARGBFFFF images)
         work equally well on four channel images with other channel orderings such as RGBA8888 or BGRAFFFF.
         */
        error = vImageEqualization_ARGB8888(
            &sourceBuffer,
            &destinationBuffer,
            vImage_Flags(kvImageLeaveAlphaUnchanged))
        
        guard error == kvImageNoError else {
            throw EqualizationImageProcessorError.equalizationOperationFailed
        }
        
        let outputCVImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(outputPixelBuffer).takeRetainedValue()
        vImageCVImageFormat_SetColorSpace(outputCVImageFormat,
                                          CGColorSpaceCreateDeviceRGB())
        
        error = vImageBuffer_CopyToCVPixelBuffer(&destinationBuffer,
                                                 &format,
                                                 outputPixelBuffer,
                                                 outputCVImageFormat,
                                                 nil,
                                                 vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            throw EqualizationImageProcessorError.equalizationOperationFailed
        }
    }
}
