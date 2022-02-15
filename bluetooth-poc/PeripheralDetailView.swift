//
//  PeripheralDetailView.swift
//  bluetooth-poc
//
//  Created by gurrium on 2022/02/15.
//

import SwiftUI
import CoreBluetooth

struct PeripheralDetailView: View {
//    @Binding var peripheral: CBPeripheral
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct PeripheralDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PeripheralDetailView()
    }
}

final class PeripheralDetailViewState: ObservableObject {
    let centralManager: CBCentralManager
    let peripheral: CBPeripheral

    init(centralManager: CBCentralManager, peripheral: CBPeripheral) {
        self.centralManager = centralManager
        self.peripheral = peripheral
    }

    func onAppear() {
        centralManager.connect(peripheral, options: nil)
    }
}
