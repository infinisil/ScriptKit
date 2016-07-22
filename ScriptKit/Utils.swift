//
//  Utils.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 22/07/16.
//  
//

import typealias Carbon.FourCharCode

extension String {
    /// The four char code representing the last four utf8 chars in this string
    ///
    /// If the string contains less than 4 utf8 chars, it acts as if zeroes were prepended to it
    ///
    /// **Examples**:
    /// ```
    /// "abc"				=> 0x  616263
    /// "Highway to Hell"	=> 0x48656c6c
    /// "😂"				=> 0xf09f9882
    /// ```
    var fourCharCode : FourCharCode {
        return utf8.suffix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }
}
