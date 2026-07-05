import AppKit
import Vision

enum TextRecognizer {
  enum RecognitionError: Error {
    case invalidImage
  }

  static func recognizeText(in image: NSImage) async throws -> String {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      throw RecognitionError.invalidImage
    }

    return try await Task.detached(priority: .userInitiated) {
      let barcodeRequest = VNDetectBarcodesRequest()

      let textRequest = VNRecognizeTextRequest()
      textRequest.recognitionLevel = .accurate
      textRequest.recognitionLanguages = ["ru-RU", "en-US"]
      textRequest.usesLanguageCorrection = true

      try VNImageRequestHandler(cgImage: cgImage).perform([barcodeRequest, textRequest])

      // Barcodes (QR, DataMatrix, EAN, Code128, ...) take priority over plain text:
      // when the image contains a decodable code, its payload is the result.
      // GS1 payloads (e.g. DataMatrix from marking labels) are kept verbatim,
      // including the invisible GS (0x1D) field separators.
      var seen = Set<String>()
      let payloads = (barcodeRequest.results ?? [])
        .compactMap { $0.payloadStringValue }
        .filter { !$0.isEmpty && seen.insert($0).inserted }
      if !payloads.isEmpty {
        return payloads.joined(separator: "\n")
      }

      return (textRequest.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
    }.value
  }
}
