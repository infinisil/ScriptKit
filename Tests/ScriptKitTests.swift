//
//  ScriptKitTests.swift
//  ScriptKitTests
//
//  Created by Silvan Mosberger on 21/07/16.
//
//

import XCTest
@testable import ScriptKit

class ScriptKitTests: XCTestCase {
    func testFourCharCode() {
        func t(_ string: String, _ fourCharCode: UInt32, line: UInt = #line) {
            let actual = string.fourCharCode
            XCTAssertEqual(actual, fourCharCode, "Four char code of \"\(string)\" should be 0x\(String(fourCharCode, radix: 16)) but was 0x\(String(actual, radix: 16))", line: line)
        }
    
        t("", 0)
        t("\0\0\0\0", 0)
        t("0000", 0x30303030)
        t("1234", 0x31323334)
        t("Test", 0x54657374)
        t("What in the heavens", 0x76656e73)
        t("a", 0x61)
		t("😂", 0xf09f9882)
    }
}
