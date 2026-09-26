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
        canonicalURL: String = "https://www.amazon.com/dp/B0",
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
        {"canonicalURL":"\(canonicalURL)","source":"\(source)","title":\(encoder(title)),\
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

    @Test func aPriceInAnUnsupportedCurrencyIsLeftOutAndTheRestIsKept() async throws {
        let api = FakeTransport(json: payload(title: "Чайник", price: 7990, currency: "rub"))
        let images = FakeTransport([.binary(NetTestSupport.pngImage(width: 400, height: 400))])
        let parser = LinkParser(client: NetTestSupport.client(transport: api), imageTransport: images)
        let link = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")

        #expect(link.title == "Чайник")
        #expect(link.imageURL?.absoluteString == "https://images.example.com/a.png")
        #expect(link.imageData != nil)
        #expect(link.price == nil)
        #expect(link.currency == nil)
        #expect(link.priceLeftOut == .unsupportedCurrency("RUB"))
        #expect(link.isEmpty == false)
    }

    @Test func aSupportedCurrencyKeepsItsPrice() async throws {
        let api = FakeTransport(json: payload(price: 129, currency: " jpy "))
        let parser = LinkParser(client: NetTestSupport.client(transport: api), downloadsImages: false)
        let link = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")

        #expect(link.price == 129)
        #expect(link.currency == "JPY")
        #expect(link.priceLeftOut == nil)
    }

    @Test func anUnsupportedCurrencyWithoutAPriceIsDroppedToo() async throws {
        let api = FakeTransport(json: payload(price: nil, currency: "INR"))
        let parser = LinkParser(client: NetTestSupport.client(transport: api), downloadsImages: false)
        let link = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")

        #expect(link.title == "Product name")
        #expect(link.price == nil)
        #expect(link.currency == nil)
        #expect(link.priceLeftOut == nil, "there was no price to leave out")
    }

    private func parseWithoutCurrency(
        canonicalURL: String,
        rawURL: String? = nil,
        currency: String? = nil
    ) async throws -> ParsedLink {
        let api = FakeTransport(json: payload(canonicalURL: canonicalURL, price: 40, currency: currency))
        let images = FakeTransport([.binary(NetTestSupport.pngImage(width: 400, height: 400))])
        let parser = LinkParser(client: NetTestSupport.client(transport: api), imageTransport: images)
        return try await parser.parse(rawURL: rawURL ?? canonicalURL)
    }

    private func expectPriceLeftOutWithTitleAndImage(_ link: ParsedLink, because reason: PriceLeftOut) {
        #expect(link.price == nil)
        #expect(link.currency == nil)
        #expect(link.priceLeftOut == reason)
        #expect(link.title == "Product name")
        #expect(link.imageURL?.absoluteString == "https://images.example.com/a.png")
        #expect(link.imageData != nil)
        #expect(link.isEmpty == false)
    }

    @Test func aPathLocaleWinsOverTheHost() async throws {
        let link = try await parseWithoutCurrency(canonicalURL: "https://www.example.ca/us/en/p/lamp")
        #expect(link.price == 40)
        #expect(link.currency == "USD")
        #expect(link.priceLeftOut == nil)
    }

    @Test func aHostSuffixFillsWhenThePathSaysNothing() async throws {
        let link = try await parseWithoutCurrency(canonicalURL: "https://www.amazon.co.uk/dp/B0")
        #expect(link.price == 40)
        #expect(link.currency == "GBP")
    }

    @Test func theCurrencyIsReadFromTheLinkTheServerLandedOn() async throws {
        let link = try await parseWithoutCurrency(
            canonicalURL: "https://www.amazon.de/dp/B0",
            rawURL: "https://amzn.eu/d/abc"
        )
        #expect(link.price == 40)
        #expect(link.currency == "EUR")
    }

    @Test func aLanguageOnlySegmentInfersNothing() async throws {
        let link = try await parseWithoutCurrency(canonicalURL: "https://shop.example.com/en/p/lamp")
        expectPriceLeftOutWithTitleAndImage(link, because: .unknownCurrency)
    }

    @Test(arguments: [
        "https://allegro.pl/oferta/lamp-1",
        "https://www.example.co.uk/en-in/p/lamp",
        "https://www.amazon.com/dp/B0"
    ])
    func noSupportedCurrencyInTheLinkLeavesThePriceOut(canonicalURL: String) async throws {
        let link = try await parseWithoutCurrency(canonicalURL: canonicalURL)
        expectPriceLeftOutWithTitleAndImage(link, because: .unknownCurrency)
    }

    @Test func aSupportedCurrencyFromThePageIsNeverOverwritten() async throws {
        let link = try await parseWithoutCurrency(canonicalURL: "https://www.amazon.co.uk/dp/B0", currency: "usd")
        #expect(link.price == 40)
        #expect(link.currency == "USD")
    }

    @Test func anUnsupportedCurrencyFromThePageIsNotReplacedByTheLink() async throws {
        let link = try await parseWithoutCurrency(canonicalURL: "https://www.amazon.de/dp/B0", currency: "RUB")
        expectPriceLeftOutWithTitleAndImage(link, because: .unsupportedCurrency("RUB"))
    }

    @Test func aFailedImageDownloadDoesNotFailTheParse() async throws {
        let api = FakeTransport(json: payload())
        let images = FakeTransport([.urlFailure(.cannotConnectToHost)])
        let parser = LinkParser(client: NetTestSupport.client(transport: api), imageTransport: images)
        let link = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")
        #expect(link.title == "Product name")
        #expect(link.imageData == nil)
    }

    @Test func aLatePhotoKeepsTheTitleThePriceAndThePhotoLink() async throws {
        let api = FakeTransport(json: payload())
        let images = FakeTransport([.binary(NetTestSupport.pngImage(width: 400, height: 400))], delay: 5)
        let parser = LinkParser(
            client: NetTestSupport.client(transport: api),
            imageTransport: images,
            imageTimeout: 0.05
        )
        let started = Date()
        let link = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")

        #expect(Date().timeIntervalSince(started) < 2, "the late photo was not cancelled at its deadline")
        #expect(link.title == "Product name")
        #expect(link.price == 24.99)
        #expect(link.currency == "USD")
        #expect(link.imageURL?.absoluteString == "https://images.example.com/a.png")
        #expect(link.imageData == nil)
    }

    @Test func theServerAndThePhotoEachGetTheirOwnDeadline() async throws {
        let api = FakeTransport([.json(payload())], delay: 0.6)
        let images = FakeTransport([.binary(NetTestSupport.pngImage(width: 400, height: 400))], delay: 0.6)
        let parser = LinkParser(
            client: NetTestSupport.client(transport: api),
            imageTransport: images,
            serverTimeout: 1,
            imageTimeout: 1
        )
        let link = try await parser.parse(rawURL: "https://www.amazon.com/dp/B0")

        #expect(link.title == "Product name")
        #expect(link.imageData != nil, "the photo must not share what is left of the server's deadline")
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
            serverTimeout: 0.05,
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

@Suite struct NetLinkFinderTests {
    @Test(arguments: [
        ("Stanley Quencher https://a.co/d/abc123", "https://a.co/d/abc123"),
        ("Check this out https://www.target.com/p/x/-/A-1", "https://www.target.com/p/x/-/A-1"),
        ("Stanley Quencher H2.0 FlowState 40 oz, 4.5 stars https://a.co/d/abc123", "https://a.co/d/abc123"),
        ("https://a.co/d/abc123 3.5", "https://a.co/d/abc123"),
        ("https://a.co/d/first and then https://www.amazon.com/dp/B0", "https://a.co/d/first"),
        ("see (https://example.com/p/lamp).", "https://example.com/p/lamp"),
        ("Look (https://a.co/d/abc) nice", "https://a.co/d/abc"),
        ("(https://example.com/p/lamp_(red))", "https://example.com/p/lamp_(red)"),
        ("see (https://example.com/p/lamp_(red)).", "https://example.com/p/lamp_(red)"),
        ("Цена 7990 руб https://abcclothes.ru/catalog/bomber/", "https://abcclothes.ru/catalog/bomber/"),
        ("file:///tmp/page.html https://zara.com/x", "https://zara.com/x"),
        ("write to shop@example.com or open https://zara.com/x", "https://zara.com/x")
    ])
    func theFirstWebLinkInTheTextIsPicked(text: String, expected: String) {
        #expect(LinkParser.firstLink(in: text)?.absoluteString == expected)
    }

    @Test(arguments: [
        ("www.walmart.com/ip/1", "https://www.walmart.com/ip/1"),
        ("a.co/d/abc123", "https://a.co/d/abc123"),
        ("Look: amzn.eu/d/abc", "https://amzn.eu/d/abc"),
        ("HTTP://zara.com/x", "http://zara.com/x")
    ])
    func aLinkWithoutASchemeGetsHTTPS(text: String, expected: String) {
        #expect(LinkParser.firstLink(in: text)?.absoluteString == expected)
    }

    @Test(arguments: [
        "https://www.ikea.com/us/en/p/billy-bookcase-white-00263850/",
        "https://www.ikea.com/us/en/p/billy-bookcase-white-00263850",
        "https://www.amazon.com/dp/B0CHWRXH8B",
        "https://www2.hm.com/en_us/productpage.0685816001.html",
        "https://www.bestbuy.com/site/apple-airpods-pro/6447382.p?skuId=6447382",
        "https://it.louisvuitton.com/ita-it/prodotti/borsa-again-monogram-nvprod6550038v/M25877",
        "https://www.etsy.com/listing/1371979456/handmade-ceramic-mug?ref=hp_rv-1",
        "https://www.example.com/p/lamp_(red)",
        "https://www.example.com/p/lamp.",
        "https://www.example.com/p/lamp!",
        "https://www.example.com/p/lamp)"
    ])
    func aTextThatIsOneLinkComesBackUnchanged(link: String) {
        #expect(LinkParser.firstLink(in: link)?.absoluteString == link)
        #expect(LinkParser.firstLink(in: "  \(link)\n")?.absoluteString == link)
    }

    @Test(arguments: [
        "3.5",
        "4.5 stars",
        "v1.2",
        "not a link",
        "",
        "   ",
        "mail me at foo@bar.com",
        "ftp://files.example.com/a",
        "tel:+123456",
        "http://example"
    ])
    func textWithoutAWebLinkGivesNothing(text: String) {
        #expect(LinkParser.firstLink(in: text) == nil)
    }

    @Test func aWebURLIsTakenAsItIsAndTheTextIsNotRead() {
        var textReads = 0
        let text: () -> String? = {
            textReads += 1
            return "https://zara.com/x"
        }
        let link = LinkParser.firstLink(url: URL(string: "https://a.co/d/abc123"), text: text())
        #expect(link?.absoluteString == "https://a.co/d/abc123")
        #expect(textReads == 0)
    }

    @Test func aURLThatIsNotAWebLinkFallsThroughToTheText() {
        let fileURL = URL(fileURLWithPath: "/tmp/page.html")
        let zara = URL(string: "https://zara.com/x")
        #expect(LinkParser.firstLink(url: fileURL, text: "Lamp https://zara.com/x") == zara)
        #expect(LinkParser.firstLink(url: nil, text: "Lamp https://zara.com/x") == zara)
        #expect(LinkParser.firstLink(url: fileURL, text: "3.5") == nil)
        #expect(LinkParser.firstLink(url: nil, text: nil) == nil)
    }
}

@Suite struct NetLinkCurrencyInferenceTests {
    @Test(arguments: [
        ("https://www.zara.com/us/en/lamp-p1.html", "USD"),
        ("https://www.lego.com/en-gb/product/lamp", "GBP"),
        ("https://www.apple.com/uk/shop/product/lamp", "GBP"),
        ("https://www2.hm.com/de_de/productpage.1.html", "EUR"),
        ("https://www.nike.com/de/t/shoe", "EUR"),
        ("https://www.ikea.com/ca/fr/p/lamp", "CAD"),
        ("https://www.lego.com/fr-CH/product/lamp", "CHF"),
        ("https://www.example.com/ch_fr/p/lamp", "CHF"),
        ("https://www.example.com/en/au/p/lamp", "AUD"),
        ("https://www.bol.com/be/nl/p/lamp", "EUR"),
        ("https://www.example.ca/us/p/lamp", "USD"),
        ("https://www.example.de/gb/p/lamp", "GBP")
    ])
    func aCountryInThePathGivesItsCurrency(url: String, currency: String) throws {
        let match = try #require(LinkCurrencyInference.match(for: URL(string: url)!))
        #expect(match == LinkCurrencyInference.Match(currency: currency, source: .path))
    }

    @Test(arguments: [
        ("https://www.amazon.co.uk/dp/B0", "GBP"),
        ("https://www.amazon.com.au/dp/B0", "AUD"),
        ("https://shop.example.co.nz/p/lamp", "NZD"),
        ("https://www.amazon.co.jp/dp/B0", "JPY"),
        ("https://www.amazon.ca/dp/B0", "CAD"),
        ("https://www.example.ch/p/lamp", "CHF"),
        ("https://www.amazon.de/dp/B0", "EUR"),
        ("https://www.example.fr/p/lamp", "EUR"),
        ("https://www.example.it/p/lamp", "EUR"),
        ("https://www.example.ie/p/lamp", "EUR"),
        ("https://www.example.at/p/lamp", "EUR"),
        ("https://shop.example.us/p/lamp", "USD"),
        ("https://www.galaxus.ch/de/s1/product/lamp-1", "CHF"),
        ("https://www.canadiantire.ca/fr/pdp/lamp", "CAD"),
        ("https://www.example.es/ca/p/lamp", "EUR"),
        ("https://www.example.co.uk/cy/p/lamp", "GBP"),
        ("https://www.example.co.uk/en/p/lamp", "GBP")
    ])
    func theHostSuffixFillsWhenThePathNamesNoCountry(url: String, currency: String) throws {
        let match = try #require(LinkCurrencyInference.match(for: URL(string: url)!))
        #expect(match == LinkCurrencyInference.Match(currency: currency, source: .host))
    }

    @Test(arguments: [
        "https://www.amazon.com/dp/B0",
        "https://www.example.com/en/p/lamp",
        "https://www.example.com/ja/p/lamp",
        "https://www.amazon.com/-/es/dp/B0",
        "https://allegro.pl/oferta/lamp-1",
        "https://www.example.co.uk/en-in/p/lamp",
        "https://www.ikea.com/pl/pl/p/lamp",
        "https://rozetka.com.ua/uk/lamp/p1/",
        "https://www.example.eu/p/lamp",
        "https://www.example.com"
    ])
    func noSupportedCountryInfersNothing(url: String) {
        #expect(LinkCurrencyInference.match(for: URL(string: url)!) == nil)
    }

    @Test func everyCountryMapsToASupportedCurrency() {
        #expect(Set(LinkCurrencyInference.currencyByCountry.values) == Set(SupportedCurrencies.codes))
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
