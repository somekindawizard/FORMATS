import SwiftData
import Foundation

@Model
final class Attachment {
    var imageData: Data?
    var caption: String?
    var order: Int

    init(imageData: Data? = nil, caption: String? = nil, order: Int = 0) {
        self.imageData = imageData
        self.caption = caption
        self.order = order
    }
}
