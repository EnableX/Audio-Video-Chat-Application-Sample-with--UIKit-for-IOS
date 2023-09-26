//
//  EnxSetting.swift
//  Enx_UIKit_iOS
//
//  Created by jaykumar on 20/03/22.
//

import UIKit
import EnxRTCiOS

@objc
public enum EnxRequiredEventsOption : Int{
    case audio = 1, video,cameraSwitch,audioSwitch,groupChat,disconnect,requestFloor, requestList,muteRoom,recording,switchAT,annotation,polling,qna,lobby,roomSetting,ScreenShare
}
@objc
public enum ParticipantListOptions: Int {
    case audio,video,chat,disconnect,changeRole
}
@objc
public enum RoomSettingOptions: Int {
    case autoCopy,askToConf,connectionTime,chatAudio,participantJoin,participantLeft,startRec,stopRec,sessionExp
}
// This is for internal used to take a decission where to add aditional user demand button
private enum aditional: Int {
    case top = 1,bottom,both
}
public enum customeNotification : String {
    case TopViewColorUpdate
    case BottomViewColorUpdate
    case TopViewConfigurList
    case BottomViewConfigurList
    case NoMoreOptionAllowed
    case FewOptionPending
    case UpdateOptionView
    case CloseChatPage
    case SenduserData
    case UserUpdate
    case UserConnected
    case UserDisconnected
    case RoleChange
    case updateMenu
    case refreshMenu
  
  var description : String {
    switch self {
    case .TopViewColorUpdate: return "TopViewColorUpdate"
    case .BottomViewColorUpdate: return "BottomViewColorUpdate"
    case .TopViewConfigurList: return "TopViewConfigurList"
    case .BottomViewConfigurList: return "BottomViewConfigurList"
    case .NoMoreOptionAllowed: return "NoMoreOptionAllowed"
    case .FewOptionPending: return "FewOptionPending"
    case .UpdateOptionView: return "UpdateOptionView"
    case .CloseChatPage : return "CloseChatPage"
    case .SenduserData : return "SenduserData"
    case .UserUpdate : return "UserUpdate"
    case .UserConnected: return "UserConnected"
    case .UserDisconnected : return "UserDisconnected"
    case .RoleChange : return "RoleChange"
    case .updateMenu : return "updateMenu"
    case .refreshMenu : return "refreshMenu"
        
    }
  }
}
@objc
public enum EnxPageSlideEventName : Int {
    case EnxChat = 1,EnxPolling,EnxQnA,EnxScreenShare
}

open class EnxSetting: NSObject {
    
    @objc static public let shared = EnxSetting()
    var chatDatas : [String : [AnyObject]] = [:]
    private(set) var isConnected : Bool = false
    private(set) var bottomViewColor :UIColor = .white.withAlphaComponent(1.0)
    private(set) var roomMode : String = "group"
    private(set) var isModerator : Bool = false
    private(set) var shareOption : [String : String] = [:]
    private(set) var clientID : String!
    private(set) var enxRoom : EnxRoom!
    private(set) var moreOptionList : [EnxRequiredEventsOptionModel] = []
    private(set) var requiredEventsOptList : [EnxRequiredEventsOptionModel] = []
    private(set) var customOpt : [Int : UIButton] = [:]
    private(set) var isTopOptCreated : Bool = false
    private(set) var isButtomOptCreated : Bool = false
    private(set) var participentListOpt : [ParticipantListOptions] = []
    private(set) var sessionSettingListOpt : [RoomSettingOptions] = []
    private(set) var participantList : [[String : String]] = []
    private(set) var doesMoreOptNeeds : Bool = false
    private(set) var isKnockEnable : Bool = false
    private(set) var isUserAwated : Bool = false
    private(set) var isFloorReq : Bool = false
    private(set) var isShareReq : Bool = false
    private(set) var isCanvasReq : Bool = false
    
    @objc
    public override init(){
    }
    
    //MARK: - Chat Process like save update delete etc...
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
    func getChat(chatType : String) -> [AnyObject]{
        guard let chatData = chatDatas[chatType] else{
            return []
        }
        return chatData
    }
    //Get all Chat Data
    
    @objc
    func allChatData() -> [String : [Any]]{
        return chatDatas
    }
    //Save files
    func saveGroupFileshare(_ filesInfo : EnxSharedFileModel){
        guard var groupChat = chatDatas["groupchat"] else {
            chatDatas["groupchat"] = [filesInfo]
            return
        }
        groupChat.append(filesInfo)
        chatDatas["groupchat"] = groupChat
    }
    func updateGroupFileShare(_ filesInfo : EnxSharedFileModel){
        for model in chatDatas["groupchat"]!{
            if(model.isKind(of: EnxSharedFileModel.self)){
                let filterValue = model as! EnxSharedFileModel
                if(filterValue.text == filesInfo.text){
                    var groupFiles = chatDatas["groupchat"]
                    filesInfo.fileType = filterValue.fileType
                    let index = groupFiles!.firstIndex{$0 === filterValue}
                    groupFiles!.remove(at: index!)
                    groupFiles!.insert(filesInfo, at: index!)
                    chatDatas["groupchat"] = groupFiles
                    break
                }
            }
        }
    }
    func savePrivateFileShare(_ filesInfo : EnxSharedFileModel){
        guard var priChat = chatDatas[filesInfo.receipientsId] else {
            chatDatas[filesInfo.receipientsId] = [filesInfo]
            return
        }
        priChat.append(filesInfo)
        chatDatas[filesInfo.receipientsId] = priChat
    }
    func updatePrivateFileShare(_ filesInfo : EnxSharedFileModel){
        for model in chatDatas[filesInfo.receipientsId]!{
            if(model.isKind(of: EnxSharedFileModel.self)){
                let filterValue = model as! EnxSharedFileModel
                if(filterValue.text == filesInfo.text){
                    var privateFiles = chatDatas[filesInfo.receipientsId]
                    filesInfo.fileType = filterValue.fileType
                    let index = privateFiles!.firstIndex{$0 === filterValue}
                    privateFiles!.remove(at: index!)
                    privateFiles!.insert(filesInfo, at: index!)
                    chatDatas[filesInfo.receipientsId] = privateFiles
                    break
                }
            }
        }
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
    //Update room mode after room switch
    func updateRoomMode(withMode : String){
        self.roomMode = withMode
    }
    @objc
    func getRoomMode() -> String{
        return self.roomMode
    }
    //Update user role after role switched
    func updateUserRole(withRole : Bool){
        isModerator = withRole
    }
    @objc
    func getCurrentRole() -> Bool{
        return isModerator
    }
    //MARK: - Internal Method for checking connection, colors
    //update state once call connectd
    func connectionEstablishSuccess(_ isConnected : Bool){
        self.isConnected = isConnected
    }
    func getBottomOptionColor() -> UIColor{
        return bottomViewColor
    }
    //MARK: - Create botton Required Options
    //Internal Used
    //Create bottom options list
    func getBottomOptionList() -> [UIButton]{
        var getListOfBottomOPT : [UIButton] = []
        if(requiredEventsOptList.isEmpty){
            requiredEventsOptList = createDefaultRequiredOption([.audio,.video,.cameraSwitch,.groupChat,.audioSwitch,.disconnect,.requestList,.requestFloor,.muteRoom,.recording,.switchAT,.annotation,.polling,.qna,.lobby,.roomSetting,.ScreenShare])
            getListOfBottomOPT = createBottomCustomeOptionButton(requiredEventsOptList)
        }
        return getListOfBottomOPT
    }
    //This is Internal Method for creating the default required option model
    private func createDefaultRequiredOption(_ optionList : [EnxRequiredEventsOption]) -> [EnxRequiredEventsOptionModel]{
        var listRequiredOpt : [EnxRequiredEventsOptionModel] = []
        if let bundle = getPath(){
            for btnName in optionList{
                if(btnName == .audio){
                    let required = EnxRequiredEventsOptionModel(name: "Audio", isSelected: false, optionTag: .audio, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "audio-on", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "audio-off", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .video){
                    let required = EnxRequiredEventsOptionModel(name: "Video", isSelected: false, optionTag: .video, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "video-on", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "video-off", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .cameraSwitch){
                    let required = EnxRequiredEventsOptionModel(name: "Camera Switch", isSelected: false, optionTag: .cameraSwitch, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "camera-rotaion", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "camera-rotaion", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .audioSwitch){
                    let required = EnxRequiredEventsOptionModel(name: "Audio Switch", isSelected: false, optionTag: .audioSwitch, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "earpiece", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "speaker", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .groupChat){
                    let required = EnxRequiredEventsOptionModel(name: "Group Chat", isSelected: false, optionTag: .groupChat, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "groupChat", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "groupChat", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .disconnect){
                    let required = EnxRequiredEventsOptionModel(name: "End Call", isSelected: false, optionTag: .disconnect, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "EndCall", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "EndCall", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .requestList){
                    let required = EnxRequiredEventsOptionModel(name: "Requests", isSelected: (getisUserInFloorReq() || getisShareReq() || getisCanvas()), optionTag: .requestList, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "notification", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "notification_sel", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .muteRoom){
                    let required = EnxRequiredEventsOptionModel(name: "Room Mute", isSelected: false, optionTag: .muteRoom, isSwith: true, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "moderator-unmute", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "moderator-mute", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .recording){
                    let required = EnxRequiredEventsOptionModel(name: "Start Recording", isSelected: false, optionTag: .recording, isSwith: true, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "recording", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "recording-on", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .annotation){
                    let required = EnxRequiredEventsOptionModel(name: "Start Annotation", isSelected: false, optionTag: .annotation, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "annotation_nor", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "annotation_sel", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .switchAT){
                    let required = EnxRequiredEventsOptionModel(name: "Switch Layout", isSelected: false, optionTag: .switchAT, isSwith: true, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "gridview", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "presentorview", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .polling){
                    let required = EnxRequiredEventsOptionModel(name: "Polling", isSelected: false, optionTag: .polling, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "Polling", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "Polling_sel", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .qna){
                    let required = EnxRequiredEventsOptionModel(name: "Q&A", isSelected: false, optionTag: .qna, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "qna", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "qna_selected", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .lobby){
                    let required = EnxRequiredEventsOptionModel(name: "Lobby", isSelected: getisUserAwaited(), optionTag: .lobby, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "lobby", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "lobby_sel", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .roomSetting){
                    let required = EnxRequiredEventsOptionModel(name: "Room Setting", isSelected: false, optionTag: .roomSetting, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "setting", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "setting", ofType: "png")!))
                    listRequiredOpt.append(required)
                }else if(btnName == .ScreenShare){
                    let required = EnxRequiredEventsOptionModel(name: "Start Share", isSelected: false, optionTag: .ScreenShare, isSwith: false, eventImageNormal: UIImage(contentsOfFile: bundle.path(forResource: "share", ofType: "png")!), eventImageSelected: UIImage(contentsOfFile: bundle.path(forResource: "share", ofType: "png")!))
                    listRequiredOpt.append(required)
                }
            }
        }
        return listRequiredOpt
    }
    //default bottom required option
    private func createBottomCustomeOptionButton(_ optionsName : [EnxRequiredEventsOptionModel]) ->[UIButton]{
        var buttonList : [UIButton] = []
            for btnName in optionsName{
                let button = UIButton(type: .custom)
                //audio
                if(btnName.optionTag == .audio){
                    button.tag = EnxRequiredEventsOption.audio.rawValue
                    button.setImage(btnName.eventImageNormal!, for: .normal)
                    button.setImage(btnName.eventImageSelected, for: .selected)
                    buttonList.append(button)
                }
                //Video
                else if(btnName.optionTag == .video){
                    button.tag = EnxRequiredEventsOption.video.rawValue
                    button.setImage(btnName.eventImageNormal, for: .normal)
                    button.setImage(btnName.eventImageSelected, for: .selected)
                    buttonList.append(button)
                }
                //Camera Switch
                else if(btnName.optionTag == .cameraSwitch){
                    button.tag = EnxRequiredEventsOption.cameraSwitch.rawValue
                    button.setImage(btnName.eventImageNormal, for: .normal)
                    button.setImage(btnName.eventImageSelected, for: .selected)
                    buttonList.append(button)
                }
                //Audio Switch
                else if(btnName.optionTag == .audioSwitch){
                    button.tag = EnxRequiredEventsOption.audioSwitch.rawValue
                    button.setImage(btnName.eventImageNormal, for: .normal)
                    button.setImage(btnName.eventImageSelected, for: .selected)
                    buttonList.append(button)
                }
                //Group Chat
                else if(btnName.optionTag == .groupChat){
                    button.tag = EnxRequiredEventsOption.groupChat.rawValue
                    button.setImage(btnName.eventImageNormal, for: .normal)
                    button.setImage(btnName.eventImageSelected, for: .selected)
                    buttonList.append(button)
                }
                //Disconnect
                else if(btnName.optionTag == .disconnect){
                    button.tag = EnxRequiredEventsOption.disconnect.rawValue
                    button.setImage(btnName.eventImageNormal, for: .normal)
                    button.setImage(btnName.eventImageSelected, for: .selected)
                    buttonList.append(button)
                }
                else{
                    doesMoreOptNeeds = true
                }
            }
            if(doesMoreOptNeeds){
                //Check for More Option
                if let bundle = getPath(){
                    let button = UIButton(type: .custom)
                    button.tag = 10101
                    button.setImage(UIImage(contentsOfFile: bundle.path(forResource: "more", ofType: "png")!), for: .normal)
                    button.setImage(UIImage(contentsOfFile: bundle.path(forResource: "more_sel", ofType: "png")!), for: .selected)
                    buttonList.insert(button, at: buttonList.count - 1)
                }
            }
        return buttonList
    }
    //Create participant List option
    func getParticipantOptList () -> [ParticipantListOptions]{
        if(participentListOpt.isEmpty){
            participentListOpt = [.audio,.video,.chat,.disconnect,.changeRole]
        }
        return participentListOpt
    }
    //Update menu option after click on menu
    func updateMenuOptions( _ isSelected : Bool , eventType : EnxRequiredEventsOption){
        for (index, optionItem) in moreOptionList.enumerated(){
            if(optionItem.optionTag == eventType){
                moreOptionList.remove(at: index)
                optionItem.isSelected = isSelected
                if(eventType == .annotation){
                    if(isSelected){
                        optionItem.name = "Stop Annotation"
                    }
                    else{
                        optionItem.name = "Start Annotation"
                    }
                }
                else if(eventType == .ScreenShare){
                    if(isSelected){
                        optionItem.name = "Stop Share"
                    }
                    else{
                        optionItem.name = "Start Share"
                    }
                }
                moreOptionList.insert(optionItem, at: index)
                NotificationCenter.default.post(name: Notification.Name(customeNotification.updateMenu.rawValue), object: optionItem, userInfo: nil)
                break
            }
        }
    }
    //Create menu option
    func getMenuOpt(isKnock : Bool) -> [EnxRequiredEventsOptionModel]{
        if(moreOptionList.count > 0){
            moreOptionList.removeAll()
        }
        for item in requiredEventsOptList{
            if(item.optionTag == .audio || item.optionTag == .video || item.optionTag == .audioSwitch || item.optionTag == .cameraSwitch || item.optionTag == .disconnect || item.optionTag == .groupChat || item.optionTag == .requestFloor){
                //Dont add to list
            }else{
                if(item.optionTag == .lobby){
                    if(isKnock){
                        if(isModerator){
                            item.isSelected = getisUserAwaited()
                            moreOptionList.append(item)
                        }
                    }
                }
                else if(item.optionTag == .requestList){
                    if(isModerator){
                        item.isSelected = (getisUserInFloorReq() || getisShareReq() || getisCanvas())
                        moreOptionList.append(item)
                    }
                }
                else if(item.optionTag == .recording || item.optionTag == .muteRoom || item.optionTag == .polling || item.optionTag == .roomSetting)
                {
                    if(isModerator){
                        moreOptionList.append(item)
                    }
                }
                else{
                    moreOptionList.append(item)
                }
            }
        }
        return moreOptionList
    }
    //App faced publice Apis
    //Public method for app user to update bottom Option View Background Color
    @objc
    public func updateBottomOptionView(withColor :UIColor){
        self.bottomViewColor = withColor
        if(isConnected){
            NotificationCenter.default.post(name: Notification.Name(customeNotification.BottomViewColorUpdate.rawValue), object: withColor, userInfo: nil)
        }
    }
    //Public method for app user to configure owne button for bottom options
    @objc
    public func configureRequiredEventsOptionList(withList : [EnxRequiredEventsOptionModel]){
        self.requiredEventsOptList = withList
        let getBottomOpt = createBottomCustomeOptionButton(requiredEventsOptList)
        if(isConnected){
            NotificationCenter.default.post(name: Notification.Name(customeNotification.BottomViewConfigurList.rawValue), object: getBottomOpt, userInfo: nil)
            
            NotificationCenter.default.post(name: Notification.Name(customeNotification.refreshMenu.rawValue), object: getMenuOpt(isKnock: isKnockEnable), userInfo: nil)
        }
    }
    @objc
    public func configureRequiredEventList( withList : [EnxRequiredEventsOption.RawValue]){
        var eventList : [EnxRequiredEventsOption] = []
        for item in withList{
            eventList.append(EnxRequiredEventsOption(rawValue: item)!)
        }
        requiredEventsOptList = createDefaultRequiredOption(eventList)
        let getBottomOpt = createBottomCustomeOptionButton(requiredEventsOptList)
        if(isConnected){
            NotificationCenter.default.post(name: Notification.Name(customeNotification.BottomViewConfigurList.rawValue), object: getBottomOpt, userInfo: nil)
            NotificationCenter.default.post(name: Notification.Name(customeNotification.refreshMenu.rawValue), object: getMenuOpt(isKnock: isKnockEnable), userInfo: nil)
        }
    }
    @objc
    public func configureParticipantList(to list : [ParticipantListOptions.RawValue]){
        if(participentListOpt.count > 0){
            participentListOpt.removeAll()
        }
        for item in list{
            participentListOpt.append(ParticipantListOptions(rawValue: item)!)
        }
    }
    //Public method for app user to configure owne screen share option
    @objc
    public func setOption(forScreenShare opt: [String : String]){
        guard opt == opt else { return }
        self.shareOption = opt
    }
    //Public method for app user to get configure  screen share option
    @objc
    public func getOptionForScreenShare() ->[String : String]?{
        return self.shareOption
    }
    func setClientId(_ clientID : String){
        self.clientID = clientID
    }
    //Public method for app user to own client id
    @objc
    public func getClientID() -> String{
        return self.clientID
    }
    //Check Knock Room
    func setKnockRoom(_ isKnock : Bool){
        self.isKnockEnable = isKnock
    }
    @objc
    public func getiSKnockRoom() -> Bool{
        return self.isKnockEnable
    }
    //Check for awaitedUser
    func setAwaitedUser(_ isAwaited : Bool){
        self.isUserAwated = isAwaited
    }
    @objc
    public func getisUserAwaited() -> Bool{
        return self.isUserAwated
    }
    //CheckFloor Request
    //Check for awaitedUser
    func setFloorReqUser(_ isAwaited : Bool){
        self.isFloorReq = isAwaited
    }
    @objc
    public func getisUserInFloorReq() -> Bool{
        return self.isFloorReq
    }
    //Check Share Request
    //Check for Share
    func setShareReqUser(_ isAwaited : Bool){
        self.isShareReq = isAwaited
    }
    @objc
    public func getisShareReq() -> Bool{
        return self.isShareReq
    }
    //Check Canvas Request
    //Check for canvas
    func setCanvasReqUser(_ isAwaited : Bool){
        self.isCanvasReq = isAwaited
    }
    @objc
    public func getisCanvas() -> Bool{
        return self.isCanvasReq
    }
    //Set RoomInstance
    func setRoom(_ room : EnxRoom){
        self.enxRoom = room
    }
    @objc
    func getRoom() -> EnxRoom{
        return self.enxRoom
    }
    //Public method for app user to share app group name and key in case of screen share
    @objc
    public func setAppGroupsName( groupname : String , withUserKey keyName : String){
        EnxUtilityManager.shareInstance().setAppGroupsName(groupname, withUserKey: keyName)
    }
    //Set list of available Participants list
    func setParticipantList (_ partList : [EnxParticipantModelObject]){
        if(participantList.count > 0){
            participantList.removeAll()
        }
        for list in partList{
            var dict : [String : String] = [:]
            dict.updateValue(list.clientId, forKey: "clientId")
            dict.updateValue(list.role, forKey: "role")
            dict.updateValue(list.name, forKey: "name")
            participantList.append(dict)
        }
    }
    //Get available participant List
    @objc
    public func getParticipantList() ->[[String : String]]{
        return participantList
    }
    //Send User Data
    @objc
    public func sendUserData(_ userData : EnxSendUserDataModel){
        NotificationCenter.default.post(name: Notification.Name(customeNotification.SenduserData.rawValue), object: userData, userInfo: nil)
    }
    func getDetailsFromService(_ serviceName : String){
        //let urlStr = serviceName + "/config"
        let url = URL(string: serviceName + "/config/index.json")
        let session = URLSession.shared
        let task = session.dataTask(with: url!) { [self] data, response, error in
            if error != nil {
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                    print("Invalid Response received from the server")
                    return
                }
            guard let responseData = data else {
                    print("nil Data received from the server")
                    return
                    }
            do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String: Any] {
                        print("Main Parse data \(jsonResponse)")
                        if let hostData = jsonResponse["hosted_apps"] as? [String : Any]{
                            if let vcData = hostData["vc"] as? [String : Any]{
                                if let optionData = vcData["options"] as? [String : Any]{
                                    createButtomopt(optionData)
                                    createMenuopt(optionData)
                                    print("Parse data \(optionData)")
                                }
                            }
                        }
                        
                        } else {
                            print("data maybe corrupted or in wrong format")
                            throw URLError(.badServerResponse)
                        }
                    } catch let error {
                        print("JSON Parsing Error: \(error.localizedDescription)")
                    }
        }
        task.resume()
    }
    private func createButtomopt(_ optionlist : [String : Any]){
        var optList : [String] = []
        var isVideo : Bool = false
        var isAudio : Bool = false
        let iscameraswitch : Bool = true
        let isaudioswitch : Bool = true
        var ischat : Bool = false
        let isDisconnect : Bool = true
        for obj in optionlist.keys{
            if(obj.caseInsensitiveCompare("video_mute") == ComparisonResult.orderedSame){
                isVideo = (optionlist[obj] as! Bool)
            }else if(obj.caseInsensitiveCompare("audio_mute") == ComparisonResult.orderedSame){
                isAudio = (optionlist[obj] as! Bool)
            }else if(obj.caseInsensitiveCompare("group_chat") == ComparisonResult.orderedSame){
                ischat = (optionlist[obj] as! Bool)
            }
        }
        if(isVideo){
            optList.append("video")
        }
        if(isAudio){
            optList.append("audio")
        }
        if(iscameraswitch){
            optList.append("cameraswitch")
        }
        if(isaudioswitch){
            optList.append("audioswitch")
        }
        if(ischat){
            optList.append("chat")
        }
        if(isDisconnect){
            optList.append("disconnect")
        }
       // bottomOptionList = createBottomCustomeOptionButton(optList)
    }
    private func createMenuopt(_ optionlist : [String : Any]){
        for obj in optionlist.keys{
            if(obj.caseInsensitiveCompare("mute_all") == ComparisonResult.orderedSame){
                if((optionlist[obj] as! Bool) == true){
                   // optList.append(.muteRoom)
                }
            }else if(obj.caseInsensitiveCompare("recording") == ComparisonResult.orderedSame){
                if((optionlist[obj] as! Bool) == true){
                    //optList.append(.recording)
                }
            }else if(obj.caseInsensitiveCompare("grid_mode_switch") == ComparisonResult.orderedSame){
                //optList.append(.switchAT)
            }else if(obj.caseInsensitiveCompare("toolbar_setup") == ComparisonResult.orderedSame){
                if let subObj = optionlist[obj] as? [String : Any]{
                    if(subObj["annotation"] != nil){
                        //optList.append(.annotation)
                    }
                }
            }
        }
        if(isConnected){
           // createMenuList(optList)
        }
       
    }
    //Create Confrence Setting
    private func createConfSettingPageList(_ confSetting : [RoomSettingOptions]) -> [EnxSettingPageModel]{
       var settingPageList : [EnxSettingPageModel] = []
        let userDefault = UserDefaults.standard
        for item in confSetting{
            if(item == .autoCopy){
                //copy Link
                let autoCopy = EnxSettingPageModel()
                autoCopy.name = "Auto Copy  Invite Link"
                (userDefault.object(forKey:"autoCopy") != nil)  ?  (autoCopy.isSelected = userDefault.object(forKey:"autoCopy") as! Bool) : (autoCopy.isSelected = false)
                autoCopy.keyName = "autoCopy"
                settingPageList.append(autoCopy)
            }
            else if(item == .askToConf){
                //Need confirmation
                let askConnection = EnxSettingPageModel()
                askConnection.name = "Ask to confirm while leaving"
                (userDefault.object(forKey:"askToConf") != nil)  ?  (askConnection.isSelected = userDefault.object(forKey:"askToConf") as! Bool) : (askConnection.isSelected = false)
                askConnection.keyName = "askToConf"
                settingPageList.append(askConnection)
            }
            else if(item == .connectionTime){
                //connection Time
                 let connectionTime = EnxSettingPageModel()
                 connectionTime.name = "Show my connection time"
                (userDefault.object(forKey:"connectionTime") != nil)  ?  (connectionTime.isSelected = userDefault.object(forKey:"connectionTime") as! Bool) : (connectionTime.isSelected = false)
                connectionTime.keyName = "connectionTime"
                 settingPageList.append(connectionTime)
            }
        }
        return settingPageList
    }
    //Create Audio Setting
   private func createAudioSettingPageList(_ audioSetting : [RoomSettingOptions]) -> [EnxSettingPageModel]{
       var settingPageList : [EnxSettingPageModel] = []
       let userDefault = UserDefaults.standard
       for item in audioSetting{
           if(item == .chatAudio){
               //Chat Audio
               let chatMessage = EnxSettingPageModel()
              chatMessage.name = "Chat Message"
               (userDefault.object(forKey:"chatAudio") != nil)  ?  (chatMessage.isSelected = userDefault.object(forKey:"chatAudio") as! Bool) : (chatMessage.isSelected = false)
               chatMessage.keyName = "chatAudio"
              settingPageList.append(chatMessage)
           }else if(item == .participantJoin){
               //Participant join
               let participantJoin = EnxSettingPageModel()
               participantJoin.name = "Participant Joined"
               (userDefault.object(forKey:"participantJoin") != nil)  ?  (participantJoin.isSelected = userDefault.object(forKey:"participantJoin") as! Bool) : (participantJoin.isSelected = false)
               participantJoin.keyName = "participantJoin"
              settingPageList.append(participantJoin)
           }else if(item == .participantLeft){
               //Participant left
               let participantleft = EnxSettingPageModel()
               participantleft.name = "Participant Left"
               (userDefault.object(forKey:"participantLeft") != nil)  ?  (participantleft.isSelected = userDefault.object(forKey:"participantLeft") as! Bool) : (participantleft.isSelected = false)
               participantleft.keyName = "participantLeft"
              settingPageList.append(participantleft)
           }else if(item == .startRec){
               //Start Recording
               let startRecording = EnxSettingPageModel()
               startRecording.name = "Recording Start"
               (userDefault.object(forKey:"startRec") != nil)  ?  (startRecording.isSelected = userDefault.object(forKey:"startRec") as! Bool) : (startRecording.isSelected = false)
               startRecording.keyName = "startRec"
               settingPageList.append(startRecording)
           }else if(item == .stopRec){
               //Stop Recording
               let stopRecording = EnxSettingPageModel()
               stopRecording.name = "Recording Stop"
               (userDefault.object(forKey:"stopRec") != nil)  ?  (stopRecording.isSelected = userDefault.object(forKey:"stopRec") as! Bool) : (stopRecording.isSelected = false)
               stopRecording.keyName = "stopRec"
               settingPageList.append(stopRecording)
           }else if(item == .sessionExp){
               //Session  Expire
               let session = EnxSettingPageModel()
               session.name = "Session Expire"
               (userDefault.object(forKey:"sessionExp") != nil)  ?  (session.isSelected = userDefault.object(forKey:"sessionExp") as! Bool) : (session.isSelected = false)
               session.keyName = "sessionExp"
               settingPageList.append(session)
           }
       }
        return settingPageList
    }
    //Create menu option
    func getPageSettingOpt() -> [String :[EnxSettingPageModel]]{
        var finalEntery : [String :[EnxSettingPageModel]]!
       if sessionSettingListOpt.count > 0 {
           finalEntery = ["Confrence Setting" : createConfSettingPageList(sessionSettingListOpt), "Audio Setting" : createAudioSettingPageList(sessionSettingListOpt)]
       }
        else{
            finalEntery = ["Confrence Setting" : createConfSettingPageList([.askToConf,.connectionTime,.autoCopy]), "Audio Setting" : createAudioSettingPageList([.chatAudio,.participantJoin,.participantLeft,.startRec,.stopRec,.sessionExp])]
        }
        return finalEntery
    }
    //sessionSettingListOpt
    @objc
    public func configureRoomSettingOpt(to list : [RoomSettingOptions.RawValue]){
        if(sessionSettingListOpt.count > 0){
            sessionSettingListOpt.removeAll()
        }
        for item in list{
            sessionSettingListOpt.append(RoomSettingOptions(rawValue: item)!)
        }
    }
    //Closed chat page
    @objc
    public func closeChatPage(){
        NotificationCenter.default.post(name: Notification.Name(customeNotification.CloseChatPage.rawValue), object: nil, userInfo: nil)
    }
}
class PaddingLabel: UILabel {
    var topInset: CGFloat
    var bottomInset: CGFloat
    var leftInset: CGFloat
    var rightInset: CGFloat

    required init(withInsets top: CGFloat, _ bottom: CGFloat,_ left: CGFloat,_ right: CGFloat) {
        self.topInset = top
        self.bottomInset = bottom
        self.leftInset = left
        self.rightInset = right
        super.init(frame: CGRect.zero)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        get {
            var contentSize = super.intrinsicContentSize
            contentSize.height += topInset + bottomInset
            contentSize.width += leftInset + rightInset
            return contentSize
        }
    }
}
