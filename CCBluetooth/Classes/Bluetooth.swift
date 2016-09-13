//
//  Bluetooth.swift
//  Pods
//
//  Created by Kevin Tallevi on 7/5/16.
//
//

import Foundation
import CoreBluetooth

var thisBluetooth : Bluetooth?

public protocol BluetoothProtocol {
    func bluetoothIsAvailable()
    func bluetoothIsUnavailable()
    func bluetoothError(_ error:Error?)
}

public protocol BluetoothPeripheralProtocol {
    var serviceUUIDString:String {get}
    var autoEnableNotifications:Bool {get}
    func didDiscoverPeripheral(_ cbPeripheral:CBPeripheral)
    func didConnectPeripheral(_ cbPeripheral:CBPeripheral)
}

public protocol BluetoothServiceProtocol {
    func didDiscoverService(_ service:CBService)
    func didDiscoverServiceWithCharacteristics(_ service:CBService)
}

public protocol BluetoothCharacteristicProtocol {
    func didUpdateNotificationStateFor(_ characteristic:CBCharacteristic)
    func didUpdateValueForCharacteristic(_ cbPeripheral: CBPeripheral, descriptor:CBDescriptor, error:NSError)
    func didWriteValueForCharacteristic(_ cbPeripheral: CBPeripheral, didWriteValueFor descriptor:CBDescriptor, error: NSError?)
}

public class Bluetooth : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    public var bluetoothDelegate : BluetoothProtocol!
    public var bluetoothPeripheralDelegate : BluetoothPeripheralProtocol!
    public var bluetoothServiceDelegate : BluetoothServiceProtocol!
    public var bluetoothCharacteristicDelegate : BluetoothCharacteristicProtocol!
    
    public var autoEnableNotifications:Bool = false
    
    public var serviceUUIDString:String = ""
    public var allowDuplicates:Bool = false
    
    private var cbCentralManager : CBCentralManager?
    private var connectedPeripheral : CBPeripheral!
    private var isScanning = false
    
    public class func sharedInstance() -> Bluetooth {
        if thisBluetooth == nil {
            thisBluetooth = Bluetooth()
        }
        return thisBluetooth!
    }
    
    private override init() {
        print("Central#init")
        super.init()
        cbCentralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    public func startScanning(_ allowDuplicatesKey:Bool) {
        print("Bluetooth#startScanning")
        self.startScanningForServiceUUIDs([CBUUID(string: bluetoothPeripheralDelegate.serviceUUIDString)], allowDuplicatesKey: allowDuplicatesKey)
    }
    
    public func startScanningForServiceUUIDs(_ uuids:[CBUUID]!, allowDuplicatesKey:Bool) {
        if (!self.isScanning) {
            print("Central#startScanningForServiceUUIDs: \(uuids) allowDuplicatesKey: \(allowDuplicatesKey)")
            self.isScanning = true
            self.cbCentralManager?.scanForPeripherals(withServices: uuids, options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicatesKey])
        }
    }
    
    public func stopScanning() {
        if (self.isScanning) {
            print("Central#stopScanning")
            self.isScanning = false
            self.cbCentralManager?.stopScan()
        }
    }
    
    public func connectPeripheral(_ peripheral:CBPeripheral) {
        print("CentralManager#connectPeripheral")
        self.cbCentralManager?.connect(peripheral, options : [
            CBCentralManagerOptionShowPowerAlertKey : true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey : true,
            CBConnectPeripheralOptionNotifyOnNotificationKey : true])
    }
    
    public func disconnectPeripheral(_ peripheral:CBPeripheral) {
        self.cbCentralManager?.cancelPeripheralConnection(peripheral)
    }
    
    public func discoverAllServices(_ cbPeripheral: CBPeripheral) {
        print("Central#discoverAllServices")
        self.connectedPeripheral = cbPeripheral
        self.connectedPeripheral.delegate = self
        
        self.connectedPeripheral.discoverServices(nil)
    }
    
    public func readCharacteristic(_ characteristic:CBCharacteristic) {
        print("Central#readCharacteristic: \(characteristic)")
        self.connectedPeripheral.readValue(for: characteristic)
    }
    
    public func writeCharacteristic(_ characteristic:CBCharacteristic, data: Data) {
        print("Central#writeCharacteristic: \(characteristic) writeData: \(data)")
        self.connectedPeripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
    }
    
    //MARK CBPeripheral delegate methods
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Central#didDiscoverServices")
        
        if (error == nil) {
            for service:CBService in peripheral.services as [CBService]! {
                print("Central#discoverCharacteristics")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        } else {
            self.bluetoothDelegate.bluetoothError(error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("Peripheral#didDiscoverCharacteristicsFor")
        
        if (error == nil) {
            if(autoEnableNotifications == true) {
                for characteristic:CBCharacteristic in service.characteristics as [CBCharacteristic]! {
                    print("characteristic: \(characteristic)")
                    if (characteristic.properties.rawValue & CBCharacteristicProperties.notify.rawValue > 0) {
                        print("enabling notification")
                        self.connectedPeripheral.setNotifyValue(true, for: characteristic)
                    }
                    if (characteristic.properties.rawValue & CBCharacteristicProperties.indicate.rawValue > 0) {
                        print("Enabling indication")
                        self.connectedPeripheral.setNotifyValue(true, for: characteristic)
                    }
                }
                if ((self.bluetoothServiceDelegate?.didDiscoverServiceWithCharacteristics(service)) != nil) {
                    bluetoothServiceDelegate.didDiscoverServiceWithCharacteristics(service)
                }
            } else {
                if ((self.bluetoothServiceDelegate?.didDiscoverServiceWithCharacteristics(service)) != nil) {
                    bluetoothServiceDelegate.didDiscoverServiceWithCharacteristics(service)
                }
            }
        } else {
            self.bluetoothDelegate.bluetoothError(error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("Peripheral#didUpdateNotificationStateForCharacteristic error: \(error)")
        
        if (error == nil) {
            if ((self.bluetoothCharacteristicDelegate?.didUpdateNotificationStateFor(characteristic)) != nil) {
                bluetoothCharacteristicDelegate.didUpdateNotificationStateFor(characteristic)
            }
        } else {
            self.bluetoothDelegate.bluetoothError(error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        print("Peripheral#didUpdateValueForCharacteristic")
        
        if (error == nil) {
            if ((self.bluetoothCharacteristicDelegate?.didUpdateValueForCharacteristic(peripheral, descriptor: descriptor, error: error! as NSError)) != nil) {
            bluetoothCharacteristicDelegate.didUpdateValueForCharacteristic(peripheral, descriptor: descriptor, error: error! as NSError)
            }
        } else {
            self.bluetoothDelegate.bluetoothError(error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        print("Peripheral#didWriteValueFor")
        
        if (error == nil) {
            if ((self.bluetoothCharacteristicDelegate?.didWriteValueForCharacteristic(peripheral, didWriteValueFor: descriptor, error: error as NSError?)) != nil) {
            bluetoothCharacteristicDelegate.didWriteValueForCharacteristic(peripheral, didWriteValueFor: descriptor, error: error as NSError?)
            }
        } else {
            self.bluetoothDelegate.bluetoothError(error)
        }
    }
    
    
    // MARK CBCentralManager delegate methods
    public func centralManager(_ central: CBCentralManager, didDiscover cbPeripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber){
        print("Central#didDiscoverPeripheral \(cbPeripheral.name)")
        print("RSSI: \(RSSI)")
        bluetoothPeripheralDelegate.didDiscoverPeripheral(cbPeripheral)
    }
    
    public func centralManagerDidUpdateState(_ central:CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth powered on.")
            bluetoothDelegate.bluetoothIsAvailable()
            
        case .poweredOff:
            print("Bluetooth powered off")
            bluetoothDelegate.bluetoothIsUnavailable()
            
        case .resetting:
            print("CoreBluetooth BLE hardware is resetting")
            
        case .unauthorized:
            print("CoreBluetooth BLE state is unauthorized")
            
        case .unknown:
            print("CoreBluetooth BLE state is unknown")
            
        case .unsupported:
            print("CoreBluetooth BLE hardware is unsupported on this platform")
        }
    }
    
    public func centralManager(_:CBCentralManager, didConnect peripheral:CBPeripheral) {
        print("CentralManager#didConnect")
        self.connectedPeripheral = peripheral
        
        if(self.bluetoothDelegate != nil) {
            self.bluetoothPeripheralDelegate.didConnectPeripheral(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Central#didDisconnectPeripheral")
        
        if (error == nil) {
            
        } else {
            self.bluetoothDelegate.bluetoothError(error)
        }
    }
}