// Copyright (c) 2016, Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//

import Cocoa
import CoreBluetooth

class ViewController: NSViewController {

    @IBOutlet weak var scanButton: NSButton!
    @IBOutlet weak var deviceMenu: NSPopUpButton!
    @IBOutlet weak var useKonashi: NSButton!
    @IBOutlet weak var chooseButton: NSButton!
    @IBOutlet weak var firmwarePath: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var actionButton: NSButton!

    private enum Action: String {
        case NotReady = "Not Ready"
        case Download = "Download"
        case Abort = "Abort"
    }

    private let manager = BluetoothManager()
    private let downloader = Downloader()
    private var file: NSData? = nil
    private var actionState = Action.NotReady
    private var displayNameToUUID = Dictionary<String, String>()

    func setFirmware(path: String) {
        file = NSData(contentsOfFile: path)
        if file != nil {
            firmwarePath.stringValue = path
        } else {
            firmwarePath.stringValue = "(not found)"
        }
        checkState()
    }

    private func scanDevices() {
        displayNameToUUID.removeAll()
        deviceMenu.removeAllItems()
        deviceMenu.addItemWithTitle("No device found")
        deviceMenu.enabled = false
        manager.scan({ (uuid, name) -> Void in
            if !self.deviceMenu.enabled {
                self.deviceMenu.removeAllItems()
                self.deviceMenu.enabled = true
                self.checkState()
            }
            var displayName = uuid;
            if name != nil {
                displayName = "\(name!) (\(uuid))"
            }
            self.displayNameToUUID[displayName] = uuid
            self.deviceMenu.addItemWithTitle(displayName)
        })
    }

    private func checkState() {
        let ready = deviceMenu.enabled && file != nil
        actionState = ready ? .Download : .NotReady
        actionButton.title = actionState.rawValue
        actionButton.enabled = ready
    }

    // NSViewController:
    override func viewDidLoad() {
        super.viewDidLoad()

        useKonashi.state = 1
        firmwarePath.stringValue = ""
        progressIndicator.minValue = 0.0
        progressIndicator.maxValue = 1.0
        progressIndicator.doubleValue = 0.0

        checkState()
        scanDevices()
    }

    // IBActions
    @IBAction func didPushScanButton(sender: NSButton) {
        scanDevices()
    }

    @IBAction func didPushChooseButton(sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.beginWithCompletionHandler({ (result) -> Void in
            if result == NSFileHandlingPanelOKButton && openPanel.URL?.path != nil {
                self.setFirmware(openPanel.URL!.path!)
            }
        })
    }

    @IBAction func didPushActionButton(sender: NSButton) {
        switch actionState {
        case .NotReady:
            assertionFailure()
        case .Download:
            assert(file != nil)
            if let title = deviceMenu.selectedItem?.title, uuid = displayNameToUUID[title] {
                actionButton.enabled = false
                manager.connect(uuid, callback: { (peripheral) -> Void in
                    self.actionButton.enabled = true
                    if peripheral == nil {
                        return
                    }
                    self.actionState = .Abort
                    self.actionButton.title = self.actionState.rawValue
                    self.downloader.start(peripheral!, firmware: self.file!, useKonashi: self.useKonashi.state == 1, callback: { (result, progress) -> Void in
                        if result {
                            if progress < 2.0 {
                                self.progressIndicator.doubleValue = progress
                                return
                            } else if progress < 5.0 {
                                let alert = NSAlert()
                                alert.messageText = "May succeeded"
                                alert.informativeText = "Firmware was downloaded via Konashi OTAFU service. Because of a technical reason, we can not verify the result on OS X. Please try connecting to the device after a while. If succeeded, the device will reboot, otherwise it does nothing."
                                alert.runModal()
                            } else {
                                let alert = NSAlert()
                                alert.messageText = "Succeeded"
                                alert.runModal()
                            }
                        } else {
                            self.downloader.abort()
                            self.progressIndicator.doubleValue = 0.0
                            let alert = NSAlert()
                            alert.messageText = "Failed"
                            alert.runModal()
                        }
                        self.actionState = .Download
                        self.actionButton.title = self.actionState.rawValue
                    })
                })
            }
        case .Abort:
            downloader.abort()
            self.actionState = .Download
            self.actionButton.title = self.actionState.rawValue
            progressIndicator.doubleValue = 0.0
        }
    }

}