import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers
// usage: icon <out.png> <size> <markFraction> <bg: gradient|none|glacier> <alpha 0|1>
let a = CommandLine.arguments
let out = a[1]; let N = Int(a[2])!; let frac = Double(a[3])!; let bg = a[4]; let alpha = a[5] == "1"
func c(_ h: UInt32, _ o: CGFloat = 1) -> CGColor { CGColor(srgbRed: CGFloat((h>>16)&255)/255, green: CGFloat((h>>8)&255)/255, blue: CGFloat(h&255)/255, alpha: o) }
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
let ctx = CGContext(data: nil, width: N, height: N, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: info)!
let S = CGFloat(N)
// flip to y-down like SVG
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
var markColor = c(0x9DB8FF)
if bg == "gradient" {
  let g = CGGradient(colorsSpace: cs, colors: [c(0x262A36), c(0x0F1014)] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: S), options: [])
} else if bg == "glacier" {
  ctx.setFillColor(c(0x9DB8FF)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S)); markColor = c(0x0B0D12)
} else { ctx.clear(CGRect(x: 0, y: 0, width: S, height: S)) }
let M = S * CGFloat(frac); let k = M / 64
// optical centre: mark spans x 6..58, y 8..56 → centre (32,32)
ctx.translateBy(x: (S - M) / 2, y: (S - M) / 2); ctx.scaleBy(x: k, y: k)
ctx.setFillColor(markColor); ctx.setStrokeColor(markColor)
let bar = CGMutablePath()
bar.move(to: CGPoint(x: 8, y: 18)); bar.addLine(to: CGPoint(x: 56, y: 10)); bar.addLine(to: CGPoint(x: 56, y: 23)); bar.addLine(to: CGPoint(x: 8, y: 27)); bar.closeSubpath()
ctx.addPath(bar); ctx.setLineWidth(4); ctx.setLineJoin(.round); ctx.drawPath(using: .fillStroke)
ctx.addPath(CGPath(roundedRect: CGRect(x: 25, y: 32, width: 14, height: 24), cornerWidth: 3, cornerHeight: 3, transform: nil)); ctx.fillPath()
let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
