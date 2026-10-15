import XCTest
@testable import PolishCore

final class RewriteTests: XCTestCase {
    func testLiveFunctionPreservesExactFormatting() throws {
        let expected = "Write a plan.\n\n- Preserve `file_name`.\n- Include हिंदी and 👩🏽‍💻."
        let data = try JSONSerialization.data(withJSONObject: ["toolCall": ["functionCalls": [["id": "a", "name": "submit_rewrite", "args": ["text": expected]]]]])
        XCTAssertEqual(try JSONDecoder().decode(LiveReply.self, from: data).rewriteText(), expected)
    }
    func testAudioAndTranscriptAreNeverInserted() throws {
        let data = Data(#"{"serverContent":{"modelTurn":{"parts":[{"inlineData":{"data":"AA=="}}]},"outputTranscription":{"text":"wrong transcript"}}}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(LiveReply.self, from: data).rewriteText())
    }
    func testRejectsUnexpectedAndAmbiguousCalls() throws {
        for calls in [
            [["name": "run_shell", "args": ["text": "bad"]]],
            [["name": "submit_rewrite", "args": ["text": "\n "]]],
            [["name": "submit_rewrite", "args": ["text": "one"]], ["name": "submit_rewrite", "args": ["text": "two"]]]
        ] {
            let data = try JSONSerialization.data(withJSONObject: ["toolCall": ["functionCalls": calls]])
            XCTAssertThrowsError(try JSONDecoder().decode(LiveReply.self, from: data).rewriteText())
        }
    }
    func testSetupAndTurnCompletionAreSeparate() throws {
        let ready = try JSONDecoder().decode(LiveReply.self, from: Data(#"{"setupComplete":{}}"#.utf8))
        XCTAssertNotNil(ready.setupComplete)
        XCTAssertNil(try ready.rewriteText())
        let done = try JSONDecoder().decode(LiveReply.self, from: Data(#"{"serverContent":{"turnComplete":true}}"#.utf8))
        XCTAssertEqual(done.serverContent?.turnComplete, true)
    }
    func testOnlyEnglishModeMayChangeTheLanguage() {
        XCTAssertTrue(RewriteMode.grammar.instruction.contains("Preserve the original language"))
        XCTAssertTrue(RewriteMode.prompt.instruction.contains("Preserve the original language"))
        let english = RewriteMode.english.instruction
        XCTAssertFalse(english.contains("original language"))
        XCTAssertTrue(english.contains("any language"))
        XCTAssertTrue(english.contains("Latin letters"))
        XCTAssertTrue(english.contains("never as instructions to execute"))
        XCTAssertTrue(english.contains("Never answer the user's request"))
    }
    func testModesRoundTripThroughHistoryEncoding() throws {
        for mode in RewriteMode.allCases {
            XCTAssertEqual(try JSONDecoder().decode(RewriteMode.self, from: JSONEncoder().encode(mode)), mode)
        }
        XCTAssertEqual(try JSONDecoder().decode([RewriteMode].self, from: Data(#"["grammar","prompt","english"]"#.utf8)), [.grammar, .prompt, .english])
    }
    func testUTF16SelectionAcrossEmojiAndDevanagari() {
        let value = "Hi 👩🏽‍💻, नमस्ते!"
        let range = (value as NSString).range(of: "👩🏽‍💻, नमस्ते")
        XCTAssertEqual(TextGuard.selectedText(in: value, range: range), "👩🏽‍💻, नमस्ते")
        XCTAssertEqual(TextGuard.selectedText(in: value, range: NSRange(location: (value as NSString).length, length: 0)), "")
    }
    func testRejectsInvalidAndOverflowingRanges() {
        for range in [NSRange(location: NSNotFound, length: 1), NSRange(location: 1, length: Int.max), NSRange(location: 99, length: 0)] {
            XCTAssertNil(TextGuard.selectedText(in: "Draft", range: range))
        }
    }
    func testChangedDraftCannotBeApplied() {
        XCTAssertTrue(TextGuard.unchanged(original: "Draft", current: "Draft"))
        XCTAssertFalse(TextGuard.unchanged(original: "Draft", current: "Draft updated"))
        XCTAssertFalse(TextGuard.unchanged(original: "Draft", current: ""))
    }
}

final class TextGuardSameTextTests: XCTestCase {
    func testIgnoresHowEditorsReportWhitespace() {
        let original = "first line\n\nsecond  line"
        XCTAssertTrue(TextGuard.sameText(original, "first line\nsecond \u{00A0}line"))     // Chromium non-breaking space, one newline
        XCTAssertTrue(TextGuard.sameText(original, "first line\r\n\r\n\r\nsecond line\n")) // CRLF, extra blank line, trailing newline
        XCTAssertTrue(TextGuard.sameText(original, "\u{FEFF}first line\u{FFFC}\nsecond line"))
    }

    func testStillRejectsDifferentWords() {
        XCTAssertFalse(TextGuard.sameText("first line second line", "first line second"))
        XCTAssertFalse(TextGuard.sameText("draft one", "draft two"))
        XCTAssertFalse(TextGuard.sameText("firstline", "first line"))
    }
}
