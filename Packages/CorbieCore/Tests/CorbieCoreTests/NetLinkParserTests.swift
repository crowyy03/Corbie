import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetLinkNormalisationTests {
    @Test func normaliseTrimsAndAddsHTTPS() throws {
        #expect(LinkParser.normalize("  www.amazon.com/dp/B0  ")?.absoluteString == "https://www.amazon.com/dp/B0")
        #expect(LinkParser.normalize("https://etsy.com/listing/1")?.absoluteString == "https://etsy.com/listing/1")
        #expect(LinkParser.normalize("HTTP://zara.com/x")?.absoluteString == "http://zara.com/x")
        #expect(LinkParser.normalize("") == nil)
        #expect(LinkParser.normalize("   ") == nil)
        #expect(LinkParser.normalize("ftp://files.example.com/a") == nil)
        #expect(LinkParser.normalize("not a link") == nil)
    }

    @Test func sourceMapsOntoTheWishSource() {
        #expect(LinkParser.source(from: "amazon") == .amazon)
        #expect(LinkParser.source(from: "TikTok") == .tiktok)
        #expect(LinkParser.source(from: "generic") == .store)
        #expect(LinkParser.source(from: "something-new") == .store)
    }
}

@Suite struct NetLinkParserTests {
    private func payload(
        source: String = "amazon",
        title: String? = "Product name",
        price: Double? = 24.99,
        currency: String? = "USD",
        imageURL: String? = "https://images.example.com/a.png",
        author: String? = nil
    ) -> String {
        let encoder = { (value: String?) in value.map { "\"\($0)\"" } ?? "null" }
        let priceText = price.map { "\($0)" } ?? "null"
        return """
        {"canonicalURL":"https://www.amazon.com/dp/B0","source":"\(source)","title":\(encoder(title)),\
        "price":\(priceText),"currency":\(encoder(currency)),"imageURL":\(encoder(imageURL)),\
        "author":\(encoder(author))}
        """
    }

    @Test func parseFillsTheWishFieldsAndDownsamplesTheImage() async throws {
        let api = FakeTransport(json: payload())
        let images = FakeTransport([.binary(NetTestSupport.pngImage(width: 2400, height: 1600))])
        let parser = LinkParser(client: NetTestSupport.client(transport: api), imageTransport: images)
        let link = try await parser.parse(url: URL(string: "https://www.amazon.com/dp/B0?tag=x")!)

        #expect(link.source == .amazon)
        #expect(link.title == "Product name")
        #expect(link.price == 24.99)
        #expect(link.currency == "USD")
        #expect(link.canonicalURL.absoluteString == "https://www.amazon.com/dp/B0")

        let data = try #require(link.imageData)
        #expect(data.count < ImageDownsampler.byteLimit)
        let downsampled = try #require(ImageDownsampler.downsample(data))
        #expect(downsampled.pixelWidth <= ImageDownsampler.maxPixelSize)
        #expect(downsampled.pixelHeight <= ImageDownsampler.maxPixelSize)
        #expect(images.requestCount == 1)
    }

    @Test func theFallbackResponseLeavesTheFieldsForManualEntry() async throws {
        let api = FakeTransport(json: payload(title: nil, price: nil, currency: nil, imageURL: nil))
        let images = FakeTransport([.empty(404)])
        let parser = LinkParser(client: NetTestSupport.client(transport: api), imageTransport: images)
        let link = try await parser.parse(rawURL: "www.amazon.com/dp/B0")
        #expect(link.title == nil)
        #expect(link.price == nil)
        #expect(link.imageData == nil)
        #expect(link.currency == nil)
        #expect(images.requestCount == 0)
    }

    @Test func anOEmbedSourceBringsThePictureAndLeavesTheRestBlank() async throws {
        let api = FakeTransport(
            json: payload(source: "instagram", title: nil, price: nil, currency: nil, author: "sofia")
        )
        let images = FakeTransport([.binary(NetTestSupport.pngImage(width: 800, height: 800))])
        let parser = LinkParser(client: NetTestSupport.client(transport: api), imageTransport: images)
        let link = try await parser.parse(rawURL: "https://www.instagram.com/p/abc/")
        #expect(link.source == .instagram)
        #expect(link.title == nil)
        #expect(link.price == nil)
        #expect(link.imageData != nil)
    }

    @Test func aFailedImageDownloadDoesNotFailTheParse() async throws {
        let api = FakeTransport(json: payload())
        let images = FakeTransport([.urlFailure(.cannotConnectToHost)])
        let parser = LinkParser(client: NetTestSupport.client(transport: api), imageTransport: images)
        let link = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")
        #expect(link.title == "Product name")
        #expect(link.imageData == nil)
    }

    @Test func aServerFailureBecomesACorbieNetworkError() async throws {
        let api = FakeTransport([.json(#"{"error":"invalid_request","message":"url is required"}"#, status: 400)])
        let parser = LinkParser(client: NetTestSupport.client(transport: api), downloadsImages: false)
        do {
            _ = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")
            Issue.record("expected a failure")
        } catch let failure as CorbieError {
            #expect(failure == CorbieError.network("400 invalid_request: url is required"))
        }
    }

    @Test func aSlowUpstreamStopsAtTheDeadline() async throws {
        let api = FakeTransport([.json(payload())], delay: 5)
        let parser = LinkParser(
            client: NetTestSupport.client(transport: api),
            timeout: 0.05,
            downloadsImages: false
        )
        do {
            _ = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")
            Issue.record("expected a failure")
        } catch let failure as CorbieError {
            #expect(failure == CorbieError.network("timed out"))
        }
    }

    @Test func anEmptyLinkIsRejectedBeforeTheNetwork() async throws {
        let api = FakeTransport(json: payload())
        let parser = LinkParser(client: NetTestSupport.client(transport: api), downloadsImages: false)
        await #expect(throws: CorbieError.invalidInput("link is not a web address")) {
            _ = try await parser.parse(rawURL: "  ")
        }
        #expect(api.requestCount == 0)
    }
}

@Suite struct NetImageDownsamplerTests {
    @Test func aLargeImageShrinksToTheLongestSideLimit() throws {
        let source = NetTestSupport.pngImage(width: 2400, height: 1200)
        let result = try #require(ImageDownsampler.downsample(source))
        #expect(result.pixelWidth == 1024)
        #expect(result.pixelHeight == 512)
        #expect(result.data.count < ImageDownsampler.byteLimit)
        #expect(result.data.count < source.count)
    }

    @Test func aSmallImageKeepsItsSize() throws {
        let source = NetTestSupport.pngImage(width: 320, height: 200)
        let result = try #require(ImageDownsampler.downsample(source))
        #expect(result.pixelWidth == 320)
        #expect(result.pixelHeight == 200)
    }

    @Test func atightByteLimitForcesASmallerImage() throws {
        let source = NetTestSupport.pngImage(width: 2400, height: 2400)
        let result = try #require(ImageDownsampler.downsample(source, byteLimit: 15_000))
        #expect(result.data.count <= 15_000)
        #expect(result.pixelWidth <= ImageDownsampler.maxPixelSize)
    }

    @Test func nonImageDataIsRejected() {
        #expect(ImageDownsampler.downsample(Data()) == nil)
        #expect(ImageDownsampler.downsample(Data("<html>nope</html>".utf8)) == nil)
    }
}
