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
                List(state.discoveredPeripherals.sorted(by: { $0.key.uuidString > $1.key.uuidString }), id: \.key) { peripheral in
                    Button(peripheral.value.name ?? "?") {
                        state.connect(peripheral.value)
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
        .sheet(item: $state.connectedPeripheral, onDismiss: nil) { peripheral in
            if (state.isServicesDiscovered) {
                let descriptorValues = peripheral.services?.flatMap { service in
                    service.characteristics?.flatMap { characteristic in
                        characteristic.descriptors?.map { descriptor in
                            descriptor.value as? String ?? "Not a description"
                        }
                    }
                } ?? []
//                ForEach(descriptorValues, id: \.self) { value in
//                    Text("hoge")
//                }
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
    @Published var centralManagerState = CBManagerState.unknown {
        didSet {
            isBluetoothEnabled = centralManagerState == .poweredOn
        }
    }
    @Published var isBluetoothEnabled = false
    @Published var discoveredPeripherals = [UUID:CBPeripheral]()
    @Published var isScanning = false
    @Published var connectedPeripheral = CBPeripheral?.none
    @Published var isServicesDiscovered = false

    private let centralManager: CBCentralManager

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
        centralManager.connect(peripheral, options: nil)
    }
}

extension PeripheralListViewState: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralManagerState = central.state
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripherals[peripheral.identifier] = peripheral
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
    }
}

extension PeripheralListViewState: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
//        servi
    }
}

extension CBPeripheral: Identifiable {}
