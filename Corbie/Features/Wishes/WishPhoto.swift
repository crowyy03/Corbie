import CorbieCore
import SwiftUI
import UIKit

struct WishPhoto: View {
    @Environment(\.palette) private var palette

    let localImage: Data?
    let imageURL: String?
    let markSide: CGFloat

    static func hasSource(localImage: Data?, imageURL: String?) -> Bool {
        localImage != nil || (imageURL?.isEmpty == false)
    }

    var body: some View {
        palette.elevated
            .overlay { picture }
            .clipped()
    }

    @ViewBuilder private var picture: some View {
        if let localImage, let image = UIImage(data: localImage) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let link = imageURL, let url = URL(string: link) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    mark
                }
            }
        } else {
            mark
        }
    }

    private var mark: some View {
        CorbieMarkView(size: markSide)
            .opacity(0.4)
    }
}

struct WishThumbnail: View {
    @Environment(\.palette) private var palette

    static let side: CGFloat = 64
    static let markSide: CGFloat = 24

    let localImage: Data?
    let imageURL: String?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
    }

    var body: some View {
        WishPhoto(localImage: localImage, imageURL: imageURL, markSide: WishThumbnail.markSide)
            .frame(width: WishThumbnail.side, height: WishThumbnail.side)
            .clipShape(shape)
            .overlay(shape.strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline))
            .accessibilityHidden(true)
    }
}
