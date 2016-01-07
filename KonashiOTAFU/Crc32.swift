// Copyright (c) 2016, Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//

import Foundation

class Crc32 {

    private var result: UInt32 = 0xffffffff
    private var table = Array<UInt32>(count: 256, repeatedValue: 0)
    private var finalized = false

    init() {
        for i in 0 ... 255 {
            var c = UInt32(i)
            for _ in 0 ... 7 {
                let lsb = (c & 1) != 0
                c >>= 1
                if lsb {
                    c ^= 0xedb88320
                }
            }
            table[i] = c
        }
        reset()
    }

    func reset() {
        result = 0xffffffff
        finalized = false
    }

    func update(data: Array<UInt8>) {
        assert(!finalized)
        for c in data {
            result = (result >> 8) ^ table[Int((result ^ UInt32(c)) & 0xff)]
        }
    }

    func crc32() -> UInt32 {
        if !finalized {
            result ^= 0xffffffff
            finalized = true
        }
        return result
    }
}