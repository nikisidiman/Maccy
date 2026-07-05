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
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.recognitionLanguages = ["ru-RU", "en-US"]
      request.usesLanguageCorrection = true

      try VNImageRequestHandler(cgImage: cgImage).perform([request])

      return (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
    }.value
  }
}
