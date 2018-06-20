//
//  U2FRegistration.swift
//  SoftU2F
//
//  Created by Benjamin P Toews on 1/30/17.
//

import Foundation
import APDUiOS

let U2F_APPID_SIZE = 32

class U2FRegistration {
    // Allow using separate keychain namespace for tests.
    static var namespace = "SoftU2F Security Key"

    static var all: [U2FRegistration] {
        let kps = KeyPair.all(label: namespace)
        var regs: [U2FRegistration] = []

        kps.forEach { kp in
            guard let reg = U2FRegistration(keyPair: kp) else {
                print("Error initializing U2FRegistration")
                return
            }

            regs.append(reg)
        }

        return regs
    }

    // The number of key pairs (keys/2) in the keychain.
    static var count: Int? {
        return KeyPair.count(label: namespace)
    }

    // Fix up legacy keychain items.
    static func repair() {
        KeyPair.repair(label: namespace)
    }

    // Delete all SoftU2F keys from keychain.
    static func deleteAll() -> Bool {
        return KeyPair.delete(label: namespace)
    }

    let keyPair: KeyPair
    let applicationParameter: Data
    var counter: UInt32

    // Key handle is application label plus 50 bytes of padding. Conformance tests require key handle to be >64 bytes.
    var keyHandle: Data {
        return padKeyHandle(keyPair.applicationLabel)
    }

    var inSEP: Bool {
        return keyPair.inSEP
    }

    // Generate a new registration.
    init?(applicationParameter ap: Data, inSEP sep: Bool) {
        applicationParameter = ap

        guard let kp = KeyPair(label: U2FRegistration.namespace, inSEP: sep) else { return nil }
        keyPair = kp

        counter = 1
        writeApplicationTag()
    }

    // Find a registration with the given key handle.
    init?(keyHandle kh: Data, applicationParameter ap: Data) {
        let appLabel = unpadKeyHandle(kh)

        let kf = KnownFacets[ap] ?? "site"
        let prompt = "authenticate with \(kf)"

        guard let kp = KeyPair(label: U2FRegistration.namespace, appLabel: appLabel, signPrompt: prompt) else { return nil }
        keyPair = kp

        // Read our application parameter from the keychain and make sure it matches.
        guard let appTag = keyPair.applicationTag else { return nil }

        let counterSize = MemoryLayout<UInt32>.size
        let appTagSize = Int(U2F_APPID_SIZE)

        if appTag.count != counterSize + appTagSize {
            return nil
        }

        counter = appTag.withUnsafeBytes { (ptr:UnsafePointer<UInt32>) -> UInt32 in
            return ptr.pointee.bigEndian
        }

        applicationParameter = appTag.subdata(in: counterSize..<(counterSize + appTagSize))

        if applicationParameter != ap {
            print("Bad applicationParameter")
            return nil
        }
    }

    // Initialize a registration with all the necessary data.
    init?(keyPair kp: KeyPair) {
        keyPair = kp

        // Read our application parameter from the keychain.
        guard let appTag = keyPair.applicationTag else { return nil }

        let counterSize = MemoryLayout<UInt32>.size
        let appTagSize = Int(U2F_APPID_SIZE)

        if appTag.count != counterSize + appTagSize {
            return nil
        }

        counter = appTag.withUnsafeBytes { (ptr:UnsafePointer<UInt32>) -> UInt32 in
            return ptr.pointee.bigEndian
        }

        applicationParameter = appTag.subdata(in: counterSize..<(counterSize + appTagSize))
    }

    // Sign some data with the private key and increment our counter.
    func sign(_ data: Data) -> Data? {
        guard let sig = keyPair.sign(data) else { return nil }

        incrementCounter()

        return sig
    }

    func incrementCounter() {
        counter += 1
        writeApplicationTag()
    }

    // Persist the applicationParameter and counter in the keychain.
    func writeApplicationTag() {
        let counterSize = MemoryLayout<UInt32>.size
        let appTagSize = Int(U2F_APPID_SIZE)
        var data = Data(capacity: counterSize + appTagSize)
        var ctrBigEndian = counter.bigEndian

        data.append(Data(bytes: &ctrBigEndian, count: counterSize))
        data.append(applicationParameter)

        keyPair.applicationTag = data
    }
}
