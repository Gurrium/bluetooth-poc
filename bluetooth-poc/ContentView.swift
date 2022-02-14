//
//  ContentView.swift
//  bluetooth-poc
//
//  Created by gurrium on 2022/02/14.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @ObservedObject var state: ContentState

    var body: some View {
        Group {
            if (state.isBluetoothEnabled) {
                Button("Scan") {
                    state.scanPeripherals()
                }
                List(state.discoveredPeripherals.sorted(by: { $0.key.uuidString > $1.key.uuidString }), id: \.key) { peripheral in
                    Text(peripheral.value.name ?? "?")
                }
            } else {
                Text("Bluetooth is not enabled.")
                Text("State: \(state.centralManagerState.rawValue)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(state: ContentState())
    }
}

final class ContentState: NSObject, ObservableObject {
    @Published var centralManagerState = CBManagerState.unknown {
        didSet {
            isBluetoothEnabled = centralManagerState == .poweredOn
        }
    }
    @Published var isBluetoothEnabled = false
    @Published var discoveredPeripherals = [UUID:CBPeripheral]()

    private let centralManager: CBCentralManager

    override init() {
        centralManager = CBCentralManager()

        super.init()

        centralManager.delegate = self
    }

    func scanPeripherals() {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
}

extension ContentState: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralManagerState = central.state
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveredPeripherals[peripheral.identifier] = peripheral
    }
}
