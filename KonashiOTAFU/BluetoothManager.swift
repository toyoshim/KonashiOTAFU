// Copyright (c) 2016, Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//

import Cocoa
import CoreBluetooth

class BluetoothManager: NSObject, CBCentralManagerDelegate {

    private var manager: CBCentralManager? = nil
    private var scanCallback: ((uuid: String, name: String?) -> Void)? = nil
    private var connectCallback: ((peripheral: CBPeripheral?) -> Void)? = nil
    private var uuidToPeripheral = Dictionary<String, CBPeripheral>()

    override init() {
        super.init()
    }

    func scan(callback: (uuid: String, name: String?) -> Void) {
        manager?.stopScan()
        scanCallback = callback
        uuidToPeripheral.removeAll()
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    func connect(uuid: String, callback: (peripheral: CBPeripheral?) -> Void) {
        if connectCallback != nil {
            return callback(peripheral: nil)
        }
        if let peripheral = uuidToPeripheral[uuid] {
            connectCallback = callback
            manager?.connectPeripheral(peripheral, options: nil)
        }
    }

    // CBCentralManagerDelegate:
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn {
            central.stopScan()
            central.scanForPeripheralsWithServices(nil, options: nil)
        }
    }

    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let uuid = peripheral.identifier.UUIDString
        if scanCallback != nil && uuidToPeripheral[uuid] == nil {
            uuidToPeripheral[uuid] = peripheral
            scanCallback!(uuid: uuid, name: peripheral.name)
        }
    }

    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        assert(connectCallback != nil)
        connectCallback!(peripheral: peripheral)
        connectCallback = nil
    }

}