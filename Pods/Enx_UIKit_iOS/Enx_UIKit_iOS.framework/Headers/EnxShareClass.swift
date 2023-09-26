//
//  EnxShareClass.swift
//  Enx_UIKit_iOS
//
//  Created by jaykumar on 28/06/22.
//

import UIKit
import EnxRTCiOS
import ReplayKit


@objc
public protocol EnxScreenShareStateDelegate:AnyObject {
    func broadCast(connected date : [Any]?)
    func broadCastDisconnected()
    func failedToConnect(withBroadCast reason: [Any]?)
    func disconnectedByOwner()
    func requestedTo(exitRoom : [Any]?)
   
}

open class EnxShareClass: NSObject {
    private(set) var room : EnxRoom! = EnxRoom()
    weak var delegate: EnxScreenShareStateDelegate?
    
    @objc
    public init(screenShare token : String, withAppGroupName groupName : String , withUserKey userKey : String, delegate : EnxScreenShareStateDelegate?){
        super.init()
        self.delegate = delegate 
        EnxUtilityManager.shareInstance().setAppGroupsName(groupName, withUserKey: userKey)
        connectWithRoom(forScreenShare: token)
    }
    //Connect Room for screen share
    private func connectWithRoom(forScreenShare token : String){
        self.room.connect(withScreenshare: token, withScreenDelegate: self)
    }
    //Stop screen share
    @objc
    public func stopStreenShare(){
        self.room.stopScreenShare()
    }
    //stop send frame over media channel
    @objc
    public func processFrame(buffer sampleBuffer : CVPixelBuffer, withTimeStamp timeStamp : Int64){
        self.room.sendVideoBuffer(sampleBuffer, withTimeStamp: timeStamp)
    }
}
//MARK: - BroadCast Delegate
extension EnxShareClass : EnxBroadCastDelegate{
    //when user connected through room for share
    public func broadCastConnected() {
        if(EnxSetting.shared.getOptionForScreenShare() != nil && EnxSetting.shared.getOptionForScreenShare()!.count > 0){
            self.room.startScreenShare(EnxSetting.shared.getOptionForScreenShare()!)
        }
        else{
            self.room.startScreenShare()
        }
    }
    public func didStartBroadCast(_ data: [Any]?) {
        delegate?.broadCast(connected: data)
    }
    public func didStoppedBroadCast(_ data: [Any]?) {
        self.room.disconnect()
    }
    
    public func broadCastDisconnected() {
        delegate?.broadCastDisconnected()
        self.room = nil
    }
    public func failedToConnect(withBroadCast reason: [Any]) {
        delegate?.failedToConnect(withBroadCast: reason)
    }
    public func disconnectedByOwner() {
        delegate?.disconnectedByOwner()
    }
    public func didRequestedExitRoom(_ Data: [Any]?) {
        delegate?.requestedTo(exitRoom: Data)
    }
}

