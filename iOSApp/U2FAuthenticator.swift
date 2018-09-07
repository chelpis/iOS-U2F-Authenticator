//
//  U2FAuthenticator.swift
//  SoftU2F
//
//  Created by Benjamin P Toews on 1/25/17.
//

import Foundation
import APDUiOS
import SelfSignedCertificateiOS

typealias Callback = (_ success: Bool) -> Void

    enum Notification {
        case Register(facet: String?)
        case Authenticate(facet: String?)
    }

protocol U2FAuthenticatorUserConfirmDelegate:class{
    func askUserPermission(_ notification:Notification, skipOnce: Bool, with callback: @escaping Callback)
}


typealias HIDMessageHandler = (_ msg: Data) -> Bool

enum MessageType: UInt8 {
    case Ping = 0x81 // Echo data through local processor only
    case Msg = 0x83 // Send U2F message frame
    case Lock = 0x84 // Send lock channel command
    case Init = 0x86 // Channel initialization
    case Wink = 0x88 // Send device identification wink
    case Sync = 0xBC // Protocol resync command
    case Error = 0xBF // Error response
}


class U2FAuthenticator {
//    static let shared = U2FAuthenticator()
    private static var hasShared = false

    var running: Bool
    weak var delegate: U2FAuthenticatorUserConfirmDelegate?
    
    private let channel: FMChannel

    private var laptopIsOpen: Bool {
        return true
    }

    init?(uh: FMChannel) {
        running = false
        channel = uh
        installMsgHandler()
    }

    func start() -> Bool {
        if channel.run() {
            running = true
            return true
        }

        return false
    }

    func stop() -> Bool {
        if channel.stop() {
            running = false
            return true
        }

        return false
    }

    func installMsgHandler() {
        // TODO: ws channel
        
        channel.handle(.Msg) { (_ msg: Data) -> Bool in
            // TODO parse raw byte array to req
            let data = msg

            do {
                let ins = try APDUiOS.commandType(raw: data)
                print(ins)

                switch ins {
                case .Register:
                    try self.handleRegisterRequest(data)
                case .Authenticate:
                    try self.handleAuthenticationRequest(data)
                case .Version:
                    try self.handleVersionRequest(data)
                default:
                    self.sendError(status: .InsNotSupported)
                }
            } catch let err as APDUiOS.ResponseStatus {
                self.sendError(status: err)
            } catch {
                self.sendError(status: .OtherError)
            }

            return true
        }
    }

    func handleRegisterRequest(_ raw: Data) throws {
        print(raw)
        let req = try APDUiOS.RegisterRequest(raw: raw)

        let facet = KnownFacets[req.applicationParameter]
        let notification = Notification.Register(facet: facet)

        self.delegate?.askUserPermission(notification, skipOnce: false) { tupSuccess in
            if !tupSuccess {
                // Send no response. Otherwise Chrome will re-prompt immediately.
                return
            }

            guard let reg = U2FRegistration(applicationParameter: req.applicationParameter, inSEP: Settings.sepEnabled) else {
                print("Error creating registration.")
                self.sendError(status: .OtherError)
                return
            }

            guard let publicKey = reg.keyPair.publicKeyData else {
                print("Error getting public key")
                self.sendError(status: .OtherError)
                return
            }

            let payloadSize = 1 + req.applicationParameter.count + req.challengeParameter.count + reg.keyHandle.count + publicKey.count
            var sigPayload = Data(capacity: payloadSize)

            sigPayload.append(UInt8(0x00)) // reserved
            sigPayload.append(req.applicationParameter)
            sigPayload.append(req.challengeParameter)
            sigPayload.append(reg.keyHandle)
            sigPayload.append(publicKey)

            guard let sig = SelfSignedCertificateiOS.sign(sigPayload) else {
                print("Error signing with certificate")
                self.sendError(status: .OtherError)
                return
            }

            let resp = RegisterResponse(publicKey: publicKey, keyHandle: reg.keyHandle, certificate: SelfSignedCertificateiOS.toDer(), signature: sig)

            self.sendMsg(msg: resp)
        }
    }

    func handleAuthenticationRequest(_ raw: Data) throws {
        let req = try APDUiOS.AuthenticationRequest(raw: raw)

        guard let reg = U2FRegistration(keyHandle: req.keyHandle, applicationParameter: req.applicationParameter) else {
            sendError(status: .WrongData)
            return
        }

        if req.control == .CheckOnly {
            // success -> error response. It's weird...
            sendError(status: .ConditionsNotSatisfied)
            return
        }

        if reg.inSEP && !laptopIsOpen {
            // Can't use SEP/TouchID if laptop is closed.
            sendError(status: .OtherError)
            return
        }

        let facet = KnownFacets[req.applicationParameter]
        let notification = Notification.Authenticate(facet: facet)
        let skipTUP = reg.inSEP

        self.delegate?.askUserPermission(notification, skipOnce: skipTUP) { tupSuccess in
            if !tupSuccess {
                // Send no response. Otherwise Chrome will re-prompt immediately.
                return
            }

            let counter = reg.counter
            var ctrBigEndian = counter.bigEndian

            let payloadSize = req.applicationParameter.count + 1 + MemoryLayout<UInt32>.size + req.challengeParameter.count
            var sigPayload = Data(capacity: payloadSize)

            sigPayload.append(req.applicationParameter)
            sigPayload.append(UInt8(0x01)) // user present
            sigPayload.append(Data(bytes: &ctrBigEndian, count: MemoryLayout<UInt32>.size))
            sigPayload.append(req.challengeParameter)

            guard let sig = reg.sign(sigPayload) else {
                self.sendError(status: .OtherError)
                return
            }

            let resp = AuthenticationResponse(userPresence: 0x01, counter: counter, signature: sig)
            self.sendMsg(msg: resp)
            return
        }
    }

    func handleVersionRequest(_ raw: Data) throws {
        let _ = try APDUiOS.VersionRequest(raw: raw)
        let resp = APDUiOS.VersionResponse(version: "U2F_V2")
        sendMsg(msg: resp)
    }

    func sendError(status: APDUiOS.ResponseStatus) {
        let resp = APDUiOS.ErrorResponse(status: status)
        sendMsg(msg: resp)
    }

    func sendMsg(msg: APDUiOS.RawConvertible) {
        let _ = channel.sendMsg(data: msg.raw)
    }
}
