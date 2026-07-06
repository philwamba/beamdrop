import XCTest
@testable import BeamDropIOSCore

final class SharePayloadParserTests: XCTestCase {
    func testParsesTextAndLinks() {
        XCTAssertEqual(SharePayloadParser.parse(text: "hello"), .text("hello"))
        XCTAssertEqual(SharePayloadParser.parse(text: "https://beamdrop.test"), .link(URL(string: "https://beamdrop.test")!))
        XCTAssertNil(SharePayloadParser.parse(text: "   "))
    }

    func testParsesFilesAndPhotos() {
        let url = URL(fileURLWithPath: "/tmp/photo.jpg")

        XCTAssertEqual(SharePayloadParser.parseFile(url: url, typeIdentifier: "public.jpeg"), .file(url))
        XCTAssertEqual(SharePayloadParser.parseFile(url: url, typeIdentifier: "public.image"), .photo(url))
    }
}
