//
//  PeripheralListView.swift
//  bluetooth-poc
//
//  Created by gurrium on 2022/02/14.
//

import SwiftUI
import CoreBluetooth
import Combine

struct PeripheralListView: View {
    @ObservedObject var state: PeripheralListViewState

    var body: some View {
        Group {
            if state.isBluetoothEnabled {
                if let cadence = state.cadence {
                    Text("Cadence: \(cadence)")
                } else {
                    ProgressView()
                }

                Text("cumulativeCrankRevolutions: \(state.cumulativeCrankRevolutions ?? 0)")
                Text("crankEventTime: \(state.crankEventTime ?? 0)")

            } else {
                Text("Bluetooth is not enabled.")
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
    @Published private(set) var isBluetoothEnabled = false {
        didSet {
            if isBluetoothEnabled {
                centralManager.scanForPeripherals(withServices: [.cyclingSpeedAndCadence], options: nil)
            }
        }
    }
    @Published private(set) var cadence: Int?

    @Published private(set) var cumulativeCrankRevolutions: UInt16?
    @Published private(set) var crankEventTime: UInt16?

    private var previousCrankEventTime: UInt16?
    private var previousCumulativeCrankRevolutions: UInt16?
    private var isStoppedCounter = 0 {
        didSet {
            if isStoppedCounter > 2 {
                cadence = 0
            }
        }
    }
    private var cscValue: [UInt8]? {
        didSet {
            guard let value = cscValue else { return }

            let cumulativeCrankRevolutions = (UInt16(value[2]) << 8) + UInt16(value[1])
            let crankEventTime = (UInt16(value[4]) << 8) + UInt16(value[3])

            self.cumulativeCrankRevolutions = cumulativeCrankRevolutions
            self.crankEventTime = crankEventTime

            if let previousCumulativeCrankRevolutions = previousCumulativeCrankRevolutions,
               let previousCrankEventTime = previousCrankEventTime {
                let duration: UInt16

                if previousCrankEventTime > crankEventTime {
                    duration = UInt16((UInt32(crankEventTime) + UInt32(UInt16.max) + 1) - UInt32(previousCrankEventTime))
                } else {
                    duration = crankEventTime - previousCrankEventTime
                }

                if duration > 0 {
                    isStoppedCounter = 0
                    cadence = Int(round(
                        (Double(cumulativeCrankRevolutions - previousCumulativeCrankRevolutions) * 60)
                        /
                        (Double(duration) / 1024)
                    ))
                } else {
                    isStoppedCounter += 1
                }
            }

            previousCumulativeCrankRevolutions = cumulativeCrankRevolutions
            previousCrankEventTime = crankEventTime
        }
    }

    private let centralManager: CBCentralManager
    private var peripheral: CBPeripheral?

    override init() {
        centralManager = CBCentralManager()

        super.init()

        centralManager.delegate = self
    }
}

extension PeripheralListViewState: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothEnabled = central.state == .poweredOn
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([.cyclingSpeedAndCadence])
    }
}

extension PeripheralListViewState: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == .cyclingSpeedAndCadence }) else { return }

        peripheral.discoverCharacteristics([.cscMeasurement], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == .cscMeasurement}),
              characteristic.properties.contains(.notify) else { return }

        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else { return }

        cscValue = [UInt8](value)
    }
}

struct Item: Identifiable {
    var id: UUID
    var description: String
    var content: Any? = nil
    var subItems: [Item]?
}

extension CBUUID {
    static var cyclingSpeedAndCadence: Self { Self.init(string: "1816") }
    static var cscMeasurement: Self { Self.init(string: "2a5b") }
}
