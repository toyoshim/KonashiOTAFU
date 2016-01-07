// Copyright (c) 2016, Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var viewController: ViewController!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let args = NSProcessInfo.processInfo().arguments
        if args.count >= 2 {
            viewController.setFirmware(args[1])
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }

}
