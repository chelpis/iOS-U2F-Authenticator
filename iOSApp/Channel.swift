//
//  Channel.swift
//  iOSApp
//
//  Created by dannynash on 2018/6/18.
//  Copyright © 2018 GitHub. All rights reserved.
//

import Foundation
import Starscream

protocol FMChannel{
    func stop()-> Bool
    func run()-> Bool
    func handle(_ type: MessageType, with handler: @escaping HIDMessageHandler)
    func sendMsg(data: Data) -> Bool
}

protocol FMChannelDelegate: class{
    func updateStatus(status: String)
}

class FMWSChannel:FMChannel{
    var socket : WebSocket?
    weak var delegate: FMChannelDelegate?
    private var handlers = [UInt8: HIDMessageHandler]()

    init(delegate: FMChannelDelegate) {
        self.delegate = delegate
        
//        socket = WebSocket(url: URL(string: "ws://192.168.50.58:9000/")!)
        socket = WebSocket(url: URL(string: "ws://192.168.50.2:15331/")!)
        
        socket!.delegate = self
        socket!.connect()
    }
    
    func stop()-> Bool {
        socket!.disconnect()
        return true
    }
    func run()-> Bool {
        socket!.connect()
        return true
    }
    func sendMsg(data: Data) -> Bool {
        socket?.write(data: data)
        return true
    }
    func handle(_ type: MessageType, with handler: @escaping HIDMessageHandler){
        handlers[type.rawValue] = handler
    }
}

extension FMWSChannel: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient){
        print("websocketDidConnect")
        self.delegate?.updateStatus(status: "websocketDidConnect")
    }
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?){
        print("websocketDidDisconnect")
        self.delegate?.updateStatus(status: "websocketDidDisconnect")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String){
        print("websocketDidReceiveMessage")
        print(text)
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data){
        print("websocketDidReceiveData")
        print(data)
        guard let handler = handlers[0x83] else {
            return
        }
        
        _ = handler(data)
    }
    
}
