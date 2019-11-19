//
//  ContentView.swift
//  BlueComm
//
//  Created by gang zhang on 11/18/19.
//  Copyright © 2019 gang zhang. All rights reserved.
//

import SwiftUI
import CoreBluetooth

struct DeviceListView: View {
    @ObservedObject var blueMngr: BlueToothMgr = BlueToothMgr()
    @State var devSel = 0
    fileprivate func extractedFunc(_ curId: String,_ devId: String) -> Text {
        return Text(curId == devId ? "Disconnect": "Connect")
    }
    
    
    var body: some View {
        NavigationView {
            VStack {
                List(blueMngr.devices) {
                    dev in
                    HStack{
                        Text(dev.name)
                        Text(dev.id)
                        Button(action: {
                            withAnimation {
                            self.selectDevice(dev)
                            }
                        },
                               label:{Text(self.blueMngr.curDeviceId == dev.id ? "Disconnect":"Connect")})
                    }
                }
                Text(blueMngr.receivedText)
                Text("Hello, World!2")
            }
        .navigationBarTitle(Text("Devices"))
            .navigationBarItems(trailing:
                HStack{
                    Button(action: scan, label:{Text("Scan")})
                    Button(action: writeRand, label:{Text("Write")})
                }
            )
        }.onAppear(perform: blueInit)
        
    }
    
    func blueInit(){
        blueMngr.createme(self)
    }
    func scan() {
        blueMngr.doScan()
    }
    func selectDevice(_ dev: DeviceInfo){
        blueMngr.doConnect(dev)
    }
    
    func writeRand() {
        blueMngr.writeData("test")
    }
}

struct DeviceInfo : Identifiable{
    var id: String
    var name: String
    var peripheral: CBPeripheral
    var writeChar: CBCharacteristic?
}

class BlueToothMgr: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var receivedText: String = "N/A"
    @Published var devices: [DeviceInfo] = []
    @Published var curDeviceId = ""
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state
        {
            
        case .unknown:
            print("peripheral unknown")
        case .resetting:
            print("peripheral resetting")
        case .unsupported:
            print("peripheral unsupported")
        case .unauthorized:
            print("peripheral unauthorized")
        case .poweredOff:
            print("peripheral poweredOff")
        case .poweredOn:
            print("peripheral poweredOn")
        @unknown default:
            print("peripheral def")
        }
    }

    
    var centralManager: CBCentralManager!
    var activeDev: DeviceInfo?
    var view: DeviceListView!
    func createme(_ mview: DeviceListView ) {
        view = mview
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func doScan() {
        devices.removeAll()
        centralManager.scanForPeripherals(withServices: nil)
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state
        {
            
        case .unknown:
            print("central unknown")
        case .resetting:
            print("central resetting")
        case .unsupported:
            print("central unsupported")
        case .unauthorized:
            print("central unauthorized")
        case .poweredOff:
            print("central poweredOff")
        case .poweredOn:
            print("central poweredOn")
            doScan()
        @unknown default:
            print("central unknown!!!!")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral.name ?? "")
        if devices.firstIndex(where: {$0.id == peripheral.identifier.description}) ?? -1 < 0 {
            devices.append(DeviceInfo(id: peripheral.identifier.description, name: peripheral.name ?? "", peripheral: peripheral,
                                      writeChar: nil
            ))
        }
    }
    
    func doConnect(_ device: DeviceInfo) {
        let peripheral = device.peripheral
        print(peripheral)
        peripheral.delegate = (self as CBPeripheralDelegate)
        if (activeDev?.id == device.id) {
            //centralManager.(peripheral)
            centralManager.cancelPeripheralConnection(peripheral)
            activeDev = nil
            curDeviceId = ""
            return
        }
        centralManager.stopScan()
        centralManager.connect(peripheral)
        activeDev = device
        curDeviceId = device.id
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected")
        peripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print("discovered services")
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("discovered chars")
        print(service)
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            print("characteristics")
            print(characteristic)
            print("properties")
            print(characteristic.properties)
            

            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
            }
          
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify")
                var found = devices.first(where: {$0.peripheral.identifier == peripheral.identifier})
                found?.writeChar = characteristic
                activeDev = found
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("did update")
        print(characteristic)
        switch characteristic.uuid {
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid) \(String(describing: characteristic.value))")
            
            receivedText = String(decoding: characteristic.value!, as: UTF8.self)
            print("Unhandled Characteristic UUID: \(characteristic.uuid) \(receivedText)")
        }
    }
    
    func writeData(_ str: String) {
        if activeDev != nil {
            print("write data \(str)")
            print(activeDev!)
            activeDev?.peripheral.writeValue(str.data(using: .utf8)!, for: (activeDev?.writeChar)!, type: CBCharacteristicWriteType.withoutResponse)
        }
    }
}

struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceListView()
    }
}
