import CoreGraphics; import ImageIO; import Foundation; import UniformTypeIdentifiers
let a = CommandLine.arguments
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
if a.count == 3 { // probe: print luminance along row y
  let y = Int(a[2])!; let r = img.cropping(to: CGRect(x: 0, y: y, width: img.width, height: 1))!
  let ctx = CGContext(data: nil, width: img.width, height: 1, bitsPerComponent: 8, bytesPerRow: img.width*4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.draw(r, in: CGRect(x: 0, y: 0, width: img.width, height: 1))
  let p = ctx.data!.bindMemory(to: UInt8.self, capacity: img.width*4)
  var last = -1; var out = ""
  for x in 0..<img.width { let v = Int(p[x*4]) + Int(p[x*4+1]) + Int(p[x*4+2]); let b = v > 66 ? 1 : 0; if b != last { out += "\(x):\(b) "; last = b } }
  print(out); exit(0)
}
let x = Int(a[3])!, y = Int(a[4])!, w = Int(a[5])!, h = Int(a[6])!
let c = img.cropping(to: CGRect(x: x, y: y, width: w, height: h))!
let tw = Int(a[7])!; let th = h * tw / w
let ctx = CGContext(data: nil, width: tw, height: th, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high; ctx.draw(c, in: CGRect(x: 0, y: 0, width: tw, height: th))
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, ctx.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary); CGImageDestinationFinalize(d)
