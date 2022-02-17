//
//  PeripheralListView.swift
//  bluetooth-poc
//
//  Created by gurrium on 2022/02/14.
//

import SwiftUI
import CoreBluetooth

struct PeripheralListView: View {
    @ObservedObject var state: PeripheralListViewState

    var body: some View {
        Group {
            if (state.isBluetoothEnabled) {
                let peripherals: [CBPeripheral] = state.discoveredPeripherals.sorted(by: { $0.identifier.uuidString > $1.identifier.uuidString })
                List(peripherals, id: \.identifier) { peripheral in
                    Button(peripheral.name ?? "unnamed") {
                        state.connect(peripheral)
                    }

                    if let services = peripheral.services {
                        ForEach(services, id: \.uuid) { service in
                            Button(service.uuid.description) {
                                state.discoverCharacteristics(for: service, of: peripheral)
                            }

                            if let characteristics = service.characteristics {
                                ForEach(characteristics, id: \.uuid) { characteristic in
                                    Button(characteristic.uuid.description) {
                                        state.readValue(for: characteristic, of: peripheral)
                                    }

                                    if let data = characteristic.value {
                                        Text(String(decoding: data, as: UTF8.self))
                                    } else {
                                        Text("no data")
                                    }
                                }
                            }
                        }
                    }
                }
                Button("Tap to \(state.isScanning ? "stop" : "start") scanning") {
                    state.toggleScanningPeripherals()
                }
                .padding()
                .tint(state.isScanning ? .gray : .blue)
                .buttonBorderShape(.roundedRectangle)
                .buttonStyle(.borderedProminent)
            } else {
                Text("Bluetooth is not enabled.")
                Text("State: \(state.centralManagerState.rawValue)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PeripheralListView(state: .init())
    }
}

final class PeripheralListViewState: NSObject, ObservableObject {
    @Published private(set) var centralManagerState = CBManagerState.unknown {
        didSet {
            isBluetoothEnabled = centralManagerState == .poweredOn
        }
    }
    @Published private(set) var isBluetoothEnabled = false
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredPeripherals = Set<CBPeripheral>()

    private let centralManager: CBCentralManager
    private var connectedPeripheral = CBPeripheral?.none

    override init() {
        centralManager = CBCentralManager()

        super.init()

        centralManager.delegate = self
    }

    func toggleScanningPeripherals() {
        if (isScanning) {
            centralManager.stopScan()
        } else {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }

        isScanning = !isScanning
    }

    func connect(_ peripheral: CBPeripheral) {
        if let connected = connectedPeripheral {
            centralManager.cancelPeripheralConnection(connected)
        }

        centralManager.connect(peripheral, options: nil)
    }

    func discoverServices(for peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func discoverCharacteristics(for service: CBService, of peripheral: CBPeripheral) {
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func readValue(for characteristic: CBCharacteristic, of peripheral: CBPeripheral) {
        peripheral.readValue(for: characteristic)
    }
}

extension PeripheralListViewState: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralManagerState = central.state
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripherals.insert(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

extension PeripheralListViewState: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        objectWillChange.send()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        objectWillChange.send()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        objectWillChange.send()
    }
}
