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
                Text("Cadence: \(state.cadence ?? -1)")
                Text("Speed: \(state.speed ?? -1)")
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
    @Published private(set) var cadence: Double?
    @Published private(set) var speed: Double?

    private var previousCrankEventTime: UInt16?
    private var previousCumulativeCrankRevolutions: UInt16?
    private var cadenceMeasurementPauseCounter = 0 {
        didSet {
            if cadenceMeasurementPauseCounter > 2 {
                cadence = 0
            }
        }
    }
    private var previousWheelEventTime: UInt16?
    private var previousCumulativeWheelRevolutions: UInt32?
    private var speedMeasurementPauseCounter = 0 {
        didSet {
            if speedMeasurementPauseCounter > 2 {
                speed = 0
            }
        }
    }
//    private var cscValues = [UUID: [UInt8]]()

    private let centralManager: CBCentralManager
    private var connectedPeripherals = Set<CBPeripheral>()

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
        connectedPeripherals.insert(peripheral)
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

//        cscValues[peripheral.identifier] = [UInt8](value)
        print([UInt8](value))
        parseCSCValue([UInt8](value))
    }

    private func parseCSCValue(_ value: [UInt8]) {
        // ref: https://www.bluetooth.com/specifications/specs/gatt-specification-supplement-5/
        if (value[0] & 0b0001) > 0 {
            if let retrieved = retrieveSpeed(from: value) {
                speedMeasurementPauseCounter = 0

                speed = retrieved
            } else {
                speedMeasurementPauseCounter += 1
            }
        }

        if (value[0] & 0b0010) > 0 {
            if let retrieved = retrieveCadence(from: value) {
                cadenceMeasurementPauseCounter = 0

                cadence = retrieved
            } else {
                cadenceMeasurementPauseCounter += 1
            }
        }
    }

    private func retrieveSpeed(from value: [UInt8]) -> Double? {
        precondition(value[0] & 0b0001 > 0, "Wheel Revolution Data Present Flag is not set")

        let cumulativeWheelRevolutions = (UInt32(value[4]) << 24) + (UInt32(value[3]) << 16) + (UInt32(value[2]) << 8) + UInt32(value[1])
        let wheelEventTime = (UInt16(value[5]) << 8) + UInt16(value[6])

        defer {
            previousCumulativeWheelRevolutions = cumulativeWheelRevolutions
            previousWheelEventTime = wheelEventTime
        }

        guard let previousCumulativeWheelRevolutions = previousCumulativeWheelRevolutions,
              let previousWheelEventTime = previousWheelEventTime else { return nil }

        let duration: UInt16

        if previousWheelEventTime > wheelEventTime {
            duration = UInt16((UInt32(wheelEventTime) + UInt32(UInt16.max) + 1) - UInt32(previousWheelEventTime))
        } else {
            duration = wheelEventTime - previousWheelEventTime
        }

        guard duration > 0 else { return nil }

        let revolutionsPerSec = Double(cumulativeWheelRevolutions - previousCumulativeWheelRevolutions) / (Double(duration) / 1024)

        // TODO: 可変にする?なくてもいいかも
        let wheelCircumference = 2105.0 // [mm]

        return revolutionsPerSec * wheelCircumference * 3600 / 1_000_000 // [km/h]
    }

    private func retrieveCadence(from value: [UInt8]) -> Double? {
        precondition(value[0] & 0b0010 > 0, "Crank Revolution Data Present Flag is not set")

        let cumulativeCrankRevolutions = (UInt16(value[2]) << 8) + UInt16(value[1])
        let crankEventTime = (UInt16(value[4]) << 8) + UInt16(value[3])

        defer {
            previousCumulativeCrankRevolutions = cumulativeCrankRevolutions
            previousCrankEventTime = crankEventTime
        }

        guard let previousCumulativeCrankRevolutions = previousCumulativeCrankRevolutions,
              let previousCrankEventTime = previousCrankEventTime else { return nil }

        let duration: UInt16

        if previousCrankEventTime > crankEventTime {
            duration = UInt16((UInt32(crankEventTime) + UInt32(UInt16.max) + 1) - UInt32(previousCrankEventTime))
        } else {
            duration = crankEventTime - previousCrankEventTime
        }

        guard duration > 0 else { return nil }

        return (Double(cumulativeCrankRevolutions - previousCumulativeCrankRevolutions) * 60)
        /
        (Double(duration) / 1024)
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
