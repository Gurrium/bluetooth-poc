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
                let peripherals = state.discoveredPeripherals.sorted(by: { $0.identifier.uuidString > $1.identifier.uuidString })
                let items: [Item] = peripherals.map { peripheral in
                        .init(
                            id: peripheral.identifier,
                            description: peripheral.name ?? "no name",
                            content: peripheral,
                            subItems: peripheral.services?.map { service in
                                    .init(
                                        id: UUID(uuidString: service.uuid.description) ?? .init(),
                                        description: service.uuid.description,
                                        content: service,
                                        subItems: service.characteristics?.map { characteristic in
                                            let valueString: String
                                            if let data = characteristic.value {
                                                valueString = String(decoding: data, as: UTF8.self)
                                            } else {
                                                valueString = "no data"
                                            }

                                            return .init(
                                                id: UUID(uuidString: characteristic.uuid.uuidString) ?? .init(),
                                                description: "\(characteristic.uuid.description): \(valueString)",
                                                content: characteristic,
                                                subItems: nil
                                            )
                                        }
                                    )
                            }
                        )
                }
                List(items, children: \.subItems) { item in
                    Button("\(item.description)") {
                        switch item.content {
                        case let peripheral as CBPeripheral:
                            state.connect(peripheral)
                        case let service as CBService:
                            state.discoverCharacteristics(for: service)
                        case let characteristic as CBCharacteristic:
                            state.readOrSubscribeValue(for: characteristic)
                        default:
                            break
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

    func discoverCharacteristics(for service: CBService) {
        service.peripheral?.discoverCharacteristics(nil, for: service)
    }

    func readOrSubscribeValue(for characteristic: CBCharacteristic) {
        if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
            characteristic.service?.peripheral?.setNotifyValue(true, for: characteristic)
        } else if characteristic.properties.contains(.read) {
            characteristic.service?.peripheral?.readValue(for: characteristic)
        }
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

struct Item: Identifiable {
    var id: UUID
    var description: String
    var content: Any? = nil
    var subItems: [Item]?
}
