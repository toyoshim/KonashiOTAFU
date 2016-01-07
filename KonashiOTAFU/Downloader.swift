// Copyright (c) 2016, Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//

import Cocoa
import CoreBluetooth

class Downloader: NSObject, CBPeripheralDelegate {

    private let ServiceBroadcomUUID = CBUUID(string: "9E5D1E47-5C13-43A0-8635-82AD38A1386F")
    private let CharacteristicBroadcomControlPointUUID = CBUUID(string: "E3DD50BF-F7A7-4E99-838E-570A086C666B")
    private let CharacteristicBroadcomDataUUID = CBUUID(string: "92E86C7A-D961-4091-B74F-2409E72EFE36")

    private enum State {
        case Idle
        case Prepare
        case Download
        case Verify
    }

    private enum Command: UInt8 {
        case PrepareDownload = 1
        case Download = 2
        case Verify = 3
    }

    private enum Response: UInt8 {
        case OK = 0
        case Unknown = 255
    }

    private var crc32 = Crc32()

    private var state = State.Idle
    private var peripheral: CBPeripheral? = nil
    private var firmware: NSData? = nil
    private var fileOffset: Int = 0
    private var callback: ((result: Bool, progress: Double) -> Void)? = nil
    private var controlPoint: CBCharacteristic? = nil
    private var data: CBCharacteristic? = nil
    private var broadcomService: CBService? = nil
    private var broadcomControlPoint: CBCharacteristic? = nil
    private var broadcomData: CBCharacteristic? = nil
    private var konashiService: CBService? = nil
    private var konashiControlPoint: CBCharacteristic? = nil
    private var konashiData: CBCharacteristic? = nil
    private var serviceCandidates = Array<CBService>()

    func start(peripheral: CBPeripheral, firmware: NSData, useKonashi: Bool, callback: (result: Bool, progress: Double) -> Void) {
        abort()
        state = .Prepare
        self.peripheral = peripheral
        self.firmware = firmware
        self.callback = callback

        peripheral.delegate = self
        peripheral.discoverServices(useKonashi ? nil : [ServiceBroadcomUUID])
    }

    func abort() {
        peripheral?.delegate = nil
        peripheral = nil
        firmware = nil
        callback = nil
        state = .Idle
        crc32.reset()

        controlPoint = nil
        data = nil
        broadcomService = nil
        broadcomControlPoint = nil
        broadcomData = nil
        konashiService = nil
        konashiControlPoint = nil
        konashiData = nil
        serviceCandidates.removeAll()
    }

    private func next(verified: Bool) {
        switch state {
        case .Prepare:
            requestDownload()
        case .Download:
            downloadNext()
        case .Verify:
            callback?(result: true, progress: verified ? 10 : 2)
            abort()
        default:
            assertionFailure()
        }
    }

    private func checkNextKonashiCandidate() -> Bool {
        assert(peripheral != nil)
        konashiService = serviceCandidates.popLast()
        konashiControlPoint = nil
        konashiData = nil
        if konashiService != nil {
            peripheral!.discoverCharacteristics(nil, forService: konashiService!)
            return true
        }
        return false
    }

    private func requestPrepareDownload() {
        assert(peripheral != nil)
        assert(controlPoint != nil)
        assert(state == .Prepare)
        peripheral!.writeValue(NSData(bytes: [Command.PrepareDownload.rawValue], length: 1), forCharacteristic: controlPoint!, type: .WithResponse)
    }

    private func requestDownload() {
        assert(peripheral != nil)
        assert(controlPoint != nil)
        assert(state == .Prepare)
        let length = firmware!.length
        var data = Array<UInt8>(count: 5, repeatedValue: 0)
        data[0] = Command.Download.rawValue
        data[1] = UInt8(length & 0xff)
        data[2] = UInt8((length >> 8) & 0xff)
        data[3] = UInt8((length >> 16) & 0xff)
        data[4] = UInt8((length >> 24) & 0xff)
        fileOffset = 0
        state = .Download
        peripheral!.writeValue(NSData(bytes: data, length: data.count), forCharacteristic: controlPoint!, type: .WithResponse)
    }

    private func downloadNext() {
        assert(peripheral != nil)
        assert(data != nil)
        assert(state == .Download)
        if fileOffset >= firmware!.length {
            return requestVerify()
        }
        let restSize = firmware!.length - fileOffset
        let size: Int = restSize > 20 ? 20 : restSize
        var payload = Array<UInt8>(count: size, repeatedValue: 0)
        firmware!.getBytes(&payload, range: NSRange(location: fileOffset, length: size))
        fileOffset += size
        crc32.update(payload)
        peripheral!.writeValue(NSData(bytes: payload, length: payload.count), forCharacteristic: data!, type: .WithResponse)
    }

    private func requestVerify() {
        assert(peripheral != nil)
        assert(controlPoint != nil)
        assert(state == .Download)
        let crc = crc32.crc32()
        var data = Array<UInt8>(count: 5, repeatedValue: 0)
        data[0] = Command.Verify.rawValue
        data[1] = UInt8(crc & 0xff)
        data[2] = UInt8((crc >> 8) & 0xff)
        data[3] = UInt8((crc >> 16) & 0xff)
        data[4] = UInt8((crc >> 24) & 0xff)
        state = .Verify
        peripheral!.writeValue(NSData(bytes: data, length: data.count), forCharacteristic: controlPoint!, type: .WithResponse)
    }

    // CBPeripheralDelegate:
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if error != nil || peripheral.services?.count == 0 {
            print("Service not found")
            callback?(result: false, progress: 0)
            return abort()
        }
        for service in peripheral.services! {
            if service.UUID.isEqualTo(ServiceBroadcomUUID) {
                broadcomService = service
            } else {
                serviceCandidates.append(service)
            }
        }
        assert(broadcomService != nil)
        peripheral.discoverCharacteristics([CharacteristicBroadcomControlPointUUID, CharacteristicBroadcomDataUUID], forService: broadcomService!)
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if error != nil || (service == broadcomService && service.characteristics?.count != 2) {
            print("Characteristics not found")
            callback?(result: false, progress: 0)
            return abort()
        }
        if service == konashiService && service.characteristics?.count == 2 {
            // Konashi provides a specific OTAFU service endpoint, but it serves
            // with a randomized UUIDs for the service and characteristics.
            // This simple check works for now, but may break in the future.
            for characteristic in service.characteristics! {
                if characteristic.properties.contains(CBCharacteristicProperties.Indicate) {
                    konashiControlPoint = characteristic
                } else {
                    konashiData = characteristic
                }
            }
            if konashiControlPoint != nil && konashiData != nil {
                peripheral.setNotifyValue(true, forCharacteristic: konashiControlPoint!)
                controlPoint = konashiControlPoint
                data = konashiData
                return
            }
        } else if service == broadcomService {
            for characteristic in service.characteristics! {
                if characteristic.UUID.isEqualTo(CharacteristicBroadcomControlPointUUID) {
                    broadcomControlPoint = characteristic
                } else if characteristic.UUID.isEqualTo(CharacteristicBroadcomDataUUID) {
                    broadcomData = characteristic
                }
            }
            assert(broadcomControlPoint != nil)
            assert(broadcomData != nil)
        }
        if !checkNextKonashiCandidate() {
            peripheral.setNotifyValue(true, forCharacteristic: broadcomControlPoint!)
            controlPoint = broadcomControlPoint
            data = broadcomData
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            print("Notification not available")
            print("\(error)")
            callback?(result: false, progress: 0)
            return abort()
        }
        requestPrepareDownload();
    }

    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("didUpdateValue")
        if error != nil {
            callback?(result: false, progress: 0)
            return abort()
        }
        if characteristic == controlPoint {
            var response = Response.Unknown
            characteristic.value?.getBytes(&response, length: 1)
            if response != .OK {
                callback?(result: false, progress: 0)
                return abort()
            }
            next(true)
        }
    }

    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            print("Write failed")
            callback?(result: false, progress: 0)
            return abort()
        }
        if characteristic == data {
            assert(firmware != nil)
            let progress: Double = Double(fileOffset) / Double(firmware!.length)
            callback?(result: true, progress: progress)
            downloadNext()
        } else if characteristic == konashiControlPoint {
            // Properly speaking, we should wait for a notified result code at
            // the control point. But Konashi has a bug to send the result not
            // to the right control point, but to the wrong control point which
            // belongs to the Broadcom OTAFU service. Since the characteristic
            // is not configured for receiving notification, OS X cannot deliver
            // the notified result. Another great news is that Konashi does not
            // implement anything for Broadcom OTAFU service. That means we
            // never succeed to subscribe for the notification.

            // Go ahead speculatively.
            next(false)
        }
    }
}