//
//  EnxSetting.swift
//  Enx_UIKit_iOS
//
//  Created by jaykumar on 20/03/22.
//

import UIKit

public enum BottomOptions: Int {
    case audio = 1, video,cameraSwitch,audioSwitch,disconnect,groupChat
}
public enum TopOptions : Int{
    case userList = 1 , menu, requestFloor, requestList
}
public enum MenuOptions: Int {
    case muteRoom = 1,recording,switchAT
}
public enum customeNotification : String {
  case TopViewColorUpdate
  case BottomViewColorUpdate
  case TopViewConfigurList
    case BottomViewConfigurList
  
  var description : String {
    switch self {
    case .TopViewColorUpdate: return "TopViewColorUpdate"
    case .BottomViewColorUpdate: return "BottomViewColorUpdate"
    case .TopViewConfigurList: return "TopViewConfigurList"
    case .BottomViewConfigurList: return "BottomViewConfigurList"
    }
  }
}


open class EnxSetting: NSObject {
    
    @objc static public let shared = EnxSetting()
    var chatDatas : [String : [EnxChatModel]] = [:]
    private(set) var isConnected : Bool = false
    private(set) var topViewColor :UIColor = .darkGray.withAlphaComponent(0.8)
    private(set) var bottomViewColor :UIColor = .white.withAlphaComponent(1.0)
    private(set) var topOptionList : [UIButton] = []
    private(set) var bottomOptionList : [UIButton] = []
    private(set) var roomMode : String = "group"
    private(set) var isModerator : Bool = false
    
    @objc
    public override init(){
    }
    //save Group Chat Message
    func saveGroupChatData(_ enxMessagfeData : EnxChatModel){
        guard var groupChat = chatDatas["groupchat"] else {
            chatDatas["groupchat"] = [enxMessagfeData]
            return
        }
        groupChat.append(enxMessagfeData)
        chatDatas["groupchat"] = groupChat
    }
    //save Private Chat Message
    func savePrivateChat(_ enxData : EnxChatModel){
        guard var priChat = chatDatas[enxData.senderID] else {
            chatDatas[enxData.senderID] = [enxData]
            return
        }
        priChat.append(enxData)
        chatDatas[enxData.senderID] = priChat
    }
    //Get a particular Chat Data
    func getChat(chatType : String) -> [EnxChatModel]{
        guard let chatData = chatDatas[chatType] else{
            return []
        }
        return chatData
    }
    //Get all Chat Data
    
    @objc
    func allChatData() -> [String : [EnxChatModel]]{
        return chatDatas
    }
    //Clear all chat history
    func cleanChatHistory(){
        if(!chatDatas.isEmpty){
            chatDatas.removeAll()
        }
    }
    //Get resource path
    func getPath() -> Bundle? {
        for bundle in Bundle.allFrameworks{
            if(bundle.bundlePath.hasSuffix("Enx_UIKit_iOS.framework")){
            return bundle
            }
        }
        return nil
    }
    //update state once call connectd
    func connectionEstablishSuccess(_ isConnected : Bool){
        self.isConnected = isConnected
    }
    func getTopOptionColor() -> UIColor{
        return topViewColor
    }
    func getBottomOptionColor() -> UIColor{
        return bottomViewColor
    }
    func getTopOptionList() -> [UIButton]{
        if(topOptionList.isEmpty){
            topOptionList = createTopCustomeOptionButton()
        }
        return topOptionList
    }
    func getBottomOptionList() -> [UIButton]{
        if(bottomOptionList.isEmpty){
            bottomOptionList = createBottomCustomeOptionButton()
        }
        return bottomOptionList
    }
    func updateRoomMode(withMode : String){
        self.roomMode = withMode
    }
    func updateUserRole(withRole : Bool){
        isModerator = withRole
    }
    @objc
    public func updateBottomOptionView(withColor :UIColor){
        self.bottomViewColor = withColor
        if(isConnected){
            NotificationCenter.default.post(name: Notification.Name(customeNotification.BottomViewColorUpdate.rawValue), object: withColor, userInfo: nil)
        }
    }
    //Set Top Bo
    
    @objc
    public func updateTopOptionView(withColor :UIColor){
        self.topViewColor = withColor
        if(isConnected){
            NotificationCenter.default.post(name: Notification.Name(customeNotification.TopViewColorUpdate.rawValue), object: withColor, userInfo: nil)
        }
    }
    
    @objc
    public func configureBottomOptionList(withList : [UIButton]){
        self.bottomOptionList = withList
        if(isConnected){
            NotificationCenter.default.post(name: Notification.Name(customeNotification.BottomViewConfigurList.rawValue), object: withList, userInfo: nil)
        }
        
    }
    
    @objc
    public func configureTopOptionList(withList : [UIButton]){
        self.topOptionList = withList
        if(isConnected){
            NotificationCenter.default.post(name: Notification.Name(customeNotification.TopViewConfigurList.rawValue), object: withList, userInfo: nil)
        }
    }
    private func createBottomCustomeOptionButton() ->[UIButton]{
        //audio
        let audioButton = UIButton(type: .custom)
        audioButton.tag = BottomOptions.audio.rawValue
        
        //video
        let videoButton = UIButton(type: .custom)
        videoButton.tag = BottomOptions.video.rawValue
        
        //switch camera
        let switchCamButton = UIButton(type: .custom)
        switchCamButton.tag = BottomOptions.cameraSwitch.rawValue
        
        //Audio switch
        let audioSwitchButton = UIButton(type: .custom)
        audioSwitchButton.tag = BottomOptions.audioSwitch.rawValue
        
        //disconnect
        let disconnectButton = UIButton(type: .custom)
        disconnectButton.tag = BottomOptions.disconnect.rawValue
        
        //disconnect
        let chatButton = UIButton(type: .custom)
        chatButton.tag = BottomOptions.groupChat.rawValue
        
        if let bundle = getPath(){
            //[UIImage imageWithContentsOfFile:dict[@"image"]];
            audioButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "audio-on", ofType: "png")!), for: .normal)
            audioButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "audio-off", ofType: "png")!), for: .selected)
            
            videoButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "video-on", ofType: "png")!), for: .normal)
            videoButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "video-off", ofType: "png")!), for: .selected)
            
            switchCamButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "camera-rotaion", ofType: "png")!), for: .normal)
            switchCamButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "camera-rotaion", ofType: "png")!), for: .normal)
            
            audioSwitchButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "earpiece", ofType: "png")!), for: .normal)
            audioSwitchButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "speaker", ofType: "png")!), for: .selected)
            
            disconnectButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "EndCall", ofType: "png")!), for: .normal)
            disconnectButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "EndCall", ofType: "png")!), for: .selected)
            
            chatButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "groupChat", ofType: "png")!), for: .normal)
            chatButton.setImage(UIImage(contentsOfFile: bundle.path(forResource: "groupChat", ofType: "png")!), for: .selected)
            
        }
        return [audioButton,videoButton,switchCamButton,audioSwitchButton,chatButton,disconnectButton]
    }
    private func createTopCustomeOptionButton() ->[UIButton]{
        //UserList
        let userList = UIButton(type: .custom)
        userList.tag = TopOptions.userList.rawValue
        
        //More option
        let moreOpt = UIButton(type: .custom)
        moreOpt.tag = TopOptions.menu.rawValue
        
        //Webinar Option
        let requestBtn = UIButton(type: .custom)
        requestBtn.tag = isModerator ? TopOptions.requestList.rawValue : TopOptions.requestFloor.rawValue
        
        
        if let bundle = getPath(){
            userList.setImage(UIImage(contentsOfFile: bundle.path(forResource: "users", ofType: "png")!), for: .normal)
            moreOpt.setImage(UIImage(contentsOfFile: bundle.path(forResource: "more", ofType: "png")!), for: .normal)
            
            requestBtn.setImage( isModerator ? UIImage(contentsOfFile: bundle.path(forResource: "notification", ofType: "png")!) : UIImage(contentsOfFile: bundle.path(forResource: "raiseHand", ofType: "png")!), for: .normal)
        }
        return roomMode == "group" ?  [userList,moreOpt] : [userList,requestBtn,moreOpt]
    }
}
