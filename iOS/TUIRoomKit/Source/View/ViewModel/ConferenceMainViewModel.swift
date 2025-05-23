//
//  ConferenceMainViewModel.swift
//  TUIRoomKit
//
//  Created by aby on 2022/12/27.
//  Copyright © 2022 Tencent. All rights reserved.
//

import Foundation
import TUICore
import RTCRoomEngine
import Factory
import Combine

protocol ConferenceMainViewResponder: AnyObject {
    func makeToast(text: String)
    func changeToolBarHiddenState()
    func setToolBarDelayHidden(isDelay: Bool)
    func showExitRoomView()
    func showAlert(title: String?, message: String?, sureTitle:String?, declineTitle: String?, sureBlock: (() -> ())?, declineBlock: (() -> ())?)
    func showAlertWithAutoConfirm(title: String?, message: String?, sureTitle:String?, declineTitle: String?, sureBlock: (() -> ())?, declineBlock: (() -> ())?, autoConfirmSeconds: Int?)
    func showRaiseHandNoticeView()
    func updateRoomInfo(roomInfo: TUIRoomInfo)
    func showPasswordView(roomId: String)
    func hidePasswordView()
    func showRepeatJoinRoomAlert()
    func updateWaterMarkLayer(text: String)
}

class ConferenceMainViewModel: NSObject {
    weak var viewResponder: ConferenceMainViewResponder? = nil
    var engineManager: EngineManager {
        EngineManager.shared
    }
    var store: RoomStore {
        engineManager.store
    }
    var roomInfo: TUIRoomInfo {
        store.roomInfo
    }
    var currentUser: UserEntity {
        store.currentUser
    }
    let roomRouter: RoomRouter = RoomRouter.shared
    private var isShownOpenCameraInviteAlert = false
    private var isShownOpenMicrophoneInviteAlert = false
    private var isShownTakeSeatInviteAlert = false
    private var selfRole: TUIRole?
    var joinConferenceParams: JoinConferenceParams?
    var startConferenceParams: StartConferenceParams?
    var isShownWaterMark: Bool = ConferenceSession.sharedInstance.implementation.isEnableWaterMark
    lazy var isSelfDisableMessage: Bool = {
       return conferenceStore.selectCurrent(UserSelectors.getDisableMessageUsers).contains(currentUser.userId)
    }()
    
    override init() {
        super.init()
        selfRole = currentUser.userRole
        subscribeEngine()
        subLogoutNotification()
    }
        
    private func subscribeEngine() {
        EngineEventCenter.shared.subscribeEngine(event: .onRoomDismissed, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onKickedOutOfRoom, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onRequestReceived, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onAllUserMicrophoneDisableChanged, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onAllUserCameraDisableChanged, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onKickedOffSeat, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onKickedOffLine, observer: self)
        EngineEventCenter.shared.subscribeUIEvent(key: .TUIRoomKitService_CurrentUserRoleChanged, responder: self)
        EngineEventCenter.shared.subscribeUIEvent(key: .TUIRoomKitService_CurrentUserMuteMessage, responder: self)
        EngineEventCenter.shared.subscribeUIEvent(key: .TUIRoomKitService_SetToolBarDelayHidden, responder: self)
        EngineEventCenter.shared.subscribeUIEvent(key: .TUIRoomKitService_ChangeToolBarHiddenState, responder: self)
        EngineEventCenter.shared.subscribeUIEvent(key: .TUIRoomKitService_ShowExitRoomView, responder: self)
        EngineEventCenter.shared.subscribeUIEvent(key: .TUIRoomKitService_DismissConferenceViewController, responder: self)
        EngineEventCenter.shared.subscribeEngine(event: .onStartedRoom, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onJoinedRoom, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onGetUserListFinished, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onUserInfoChanged, observer: self)
        EngineEventCenter.shared.subscribeEngine(event: .onUserVideoStateChanged, observer: self)
    }
    
    private func subLogoutNotification() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(dismissConferenceViewForLogout),
                                               name: NSNotification.Name.TUILogoutSuccess, object: nil)
    }
    
    private func unsubLogoutNotification() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.TUILogoutSuccess, object: nil)
    }
    
    private func unsubscribeEngine() {
        EngineEventCenter.shared.unsubscribeEngine(event: .onRoomDismissed, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onKickedOutOfRoom, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onRequestReceived, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onAllUserMicrophoneDisableChanged, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onAllUserCameraDisableChanged, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onKickedOffSeat, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onKickedOffLine, observer: self)
        EngineEventCenter.shared.unsubscribeUIEvent(key: .TUIRoomKitService_CurrentUserRoleChanged, responder: self)
        EngineEventCenter.shared.unsubscribeUIEvent(key: .TUIRoomKitService_CurrentUserMuteMessage, responder: self)
        EngineEventCenter.shared.unsubscribeUIEvent(key: .TUIRoomKitService_SetToolBarDelayHidden, responder: self)
        EngineEventCenter.shared.unsubscribeUIEvent(key: .TUIRoomKitService_ChangeToolBarHiddenState, responder: self)
        EngineEventCenter.shared.unsubscribeUIEvent(key: .TUIRoomKitService_ShowExitRoomView, responder: self)
        EngineEventCenter.shared.unsubscribeUIEvent(key: .TUIRoomKitService_DismissConferenceViewController, responder: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onStartedRoom, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onJoinedRoom, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onGetUserListFinished, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onUserInfoChanged, observer: self)
        EngineEventCenter.shared.unsubscribeEngine(event: .onUserVideoStateChanged, observer: self)
    }
    
    func onViewDidLoadAction() {
        if store.isEnteredRoom {
            let roomId = startConferenceParams?.roomId ?? joinConferenceParams?.roomId
            if let roomId = roomId, store.roomInfo.roomId != roomId {
                viewResponder?.showRepeatJoinRoomAlert()
            }
            return
        }
        if startConferenceParams != nil {
            quickStartConference()
            return
        }
        if joinConferenceParams != nil {
            joinConference()
        }
    }
    
    func quickStartConference() {
        guard let startParams = startConferenceParams, !startParams.roomId.isEmpty else {
            return
        }
        ConferenceOptions.quickStart(startConferenceParams: startParams) { [weak self] roomInfo in
            guard let self = self else { return }
            guard !self.viewStore.isInternalCreation else { return }
            self.notifySuccess(roomInfo: roomInfo, event: .onStartedRoom)
        } onError: { [weak self] code, message in
            guard let self = self else { return }
            self.handleOperateConferenceFailedResult(roomId: startParams.roomId, event: .onStartedRoom, error: code, message: message)
        }
    }
    
    func joinConference() {
        guard let joinParams = joinConferenceParams, !joinParams.roomId.isEmpty else {
            return
        }
        ConferenceOptions.join(joinConferenParams: joinParams) { [weak self] roomInfo in
            guard let self = self else { return }
            self.viewResponder?.hidePasswordView()
            self.notifySuccess(roomInfo: roomInfo, event: .onJoinedRoom)
        } onError: { [weak self] code, message in
            guard let self = self else { return }
            if code == .needPassword {
                self.viewResponder?.showPasswordView(roomId: joinParams.roomId)
            } else if code == .wrongPassword {
                self.viewResponder?.makeToast(text: .wrongPasswordText)
            } else {
                self.handleOperateConferenceFailedResult(roomId: joinParams.roomId, event: .onJoinedRoom, error: code, message: message)
            }
        }
    }
    
    func notifySuccess(roomInfo: TUIRoomInfo?,
                                      event: EngineEventCenter.RoomEngineEvent) {
        let param = [
            "roomInfo" : roomInfo ?? TUIRoomInfo(),
            "error" : TUIError.success,
            "mesasge" : ""
        ] as [String : Any]
        EngineEventCenter.shared.notifyEngineEvent(event: event, param: param)
    }
    
    func notifyError(roomId: String,
                                    event: EngineEventCenter.RoomEngineEvent,
                                    error: TUIError,
                                    message: String) {
        let roomInfo = TUIRoomInfo()
        roomInfo.roomId = roomId
        let param = [
            "roomInfo" : roomInfo,
            "error" : error,
            "mesasge" : message
        ] as [String : Any]
        EngineEventCenter.shared.notifyEngineEvent(event: event, param: param)
    }
    
    func setJoinConferenceParams(params: JoinConferenceParams) {
        joinConferenceParams = params
        store.setCameraOpened(params.isOpenCamera)
        store.setSoundOnSpeaker(params.isOpenSpeaker)
    }
    
    func setStartConferenceParams(params: StartConferenceParams) {
        startConferenceParams = params
        store.setCameraOpened(params.isOpenCamera)
        store.setSoundOnSpeaker(params.isOpenSpeaker)
    }
    
    @objc func dismissConferenceViewForLogout() {
        viewResponder?.showAlertWithAutoConfirm(title: .logoutText, message: nil, sureTitle: .alertOkText, declineTitle: nil, sureBlock: {
            EngineEventCenter.shared.notifyUIEvent(key: .TUIRoomKitService_DismissConferenceViewController, param: [:])
        }, declineBlock: nil, autoConfirmSeconds: 5)
    }
    
    func handleWrongPasswordFault(roomId: String) {
        handleOperateConferenceFailedResult(roomId: roomId, event: .onJoinedRoom, error: .failed, message: "")
    }
    
    private func handleOperateConferenceFailedResult(roomId: String, event: EngineEventCenter.RoomEngineEvent, error: TUIError, message: String) {
        let errorMessage = error.description ?? message
        if !viewStore.isInternalCreation {
            notifyError(roomId: roomId, event: event, error: error, message: message)
        } else {
            EngineEventCenter.shared.notifyUIEvent(key: .TUIRoomKitService_DismissConferenceViewController, param: [:])
            if error.isCommon, !errorMessage.isEmpty {
                conferenceStore.dispatch(action: ViewActions.showToast(payload: ToastInfo(message: errorMessage)))
            }
        }
        debugPrint("TUIRoomKit error: \(event) error, \(errorMessage)")
    }
    
    func setVideoResolutionMode(isLandscape: Bool) {
        let resolutionMode: TUIResolutionMode = isLandscape ? .landscape : .portrait
        engineManager.setVideoResolutionMode(streamType: .cameraStream, resolutionMode: resolutionMode)
        engineManager.setVideoResolutionMode(streamType: .cameraStreamLow, resolutionMode: resolutionMode)
    }
    
    deinit {
        unsubscribeEngine()
        unsubLogoutNotification()
        debugPrint("deinit \(self)")
    }
    
    @Injected(\.conferenceStore) var conferenceStore: ConferenceStore
    @Injected(\.conferenceMainViewStore) var viewStore: ConferenceMainViewStore
}

extension ConferenceMainViewModel: RoomEngineEventResponder {
    func onEngineEvent(name: EngineEventCenter.RoomEngineEvent, param: [String : Any]?) {
        switch name {
        case .onRoomDismissed:
            handleRoomDismissed()
        case .onKickedOutOfRoom:
            handleKickedOutOfRoom()
        case .onAllUserMicrophoneDisableChanged:
            guard let isDisable = param?["isDisable"] as? Bool else { return }
            handleAllUserMicrophoneDisableChanged(isDisable: isDisable)
        case .onAllUserCameraDisableChanged:
            guard let isDisable = param?["isDisable"] as? Bool else { return }
            handleAllUserCameraDisableChanged(isDisable: isDisable)
        case .onKickedOffSeat:
            viewResponder?.makeToast(text: .kickedOffSeat)
        case .onRequestReceived:
            guard let request = param?["request"] as? TUIRequest else { return }
            handleReceivedRequest(request: request)
        case .onKickedOffLine:
            handleKickedOffLine()
        case .onStartedRoom:
            guard let roomInfo = param?["roomInfo"] as? TUIRoomInfo else { return }
            guard let error = param?["error"] as? TUIError else { return }
            guard error == .success else { return }
            handleStartRoom(roomInfo: roomInfo)
            var roomState = RoomInfo(with: roomInfo)
            roomState.isEnteredRoom = true
            conferenceStore.dispatch(action: RoomActions.updateRoomState(payload: roomState))
            viewResponder?.updateWaterMarkLayer(text: getWaterMarkText())
        case .onJoinedRoom:
            guard let roomInfo = param?["roomInfo"] as? TUIRoomInfo else { return }
            guard let error = param?["error"] as? TUIError else { return }
            guard error == .success else { return }
            handleJoinRoom(roomInfo: roomInfo)
            var roomState = RoomInfo(with: roomInfo)
            roomState.isEnteredRoom = true
            conferenceStore.dispatch(action: RoomActions.updateRoomState(payload: roomState))
            viewResponder?.updateWaterMarkLayer(text: getWaterMarkText())
        case .onGetUserListFinished:
            let allUsers = self.store.attendeeList.map{ UserInfo(userEntity: $0) }
            conferenceStore.dispatch(action: UserActions.updateAllUsers(payload: allUsers))
            conferenceStore.dispatch(action: ConferenceInvitationActions.getInvitationList(payload: (store.roomInfo.roomId, "", [])))
        case .onUserInfoChanged:
            guard let userInfo = param?["userInfo"] as? TUIUserInfo else { return }
            guard let modifyFlag = param?["modifyFlag"] as? TUIUserInfoModifyFlag else { return }
            guard modifyFlag.contains(.nameCard) else { return }
            guard userInfo.userId == currentUser.userId else { return }
            viewResponder?.updateWaterMarkLayer(text: getWaterMarkText())
        case .onUserVideoStateChanged:
            guard let userId = param?["userId"] as? String else { return }
            guard let streamType = param?["streamType"] as? TUIVideoStreamType else { return }
            guard let hasVideo = param?["hasVideo"] as? Bool else { return }
            guard let reason = param?["reason"] as? TUIChangeReason else { return }
            handleUserVideoStateChanged(userId: userId, streamType: streamType, hasVideo: hasVideo, reason: reason)
        default: break
        }
    }
    
    private func handleRoomDismissed() {
#if RTCube_APPSTORE
        if currentUser.userRole == .roomOwner {
            let selector = NSSelectorFromString("showAlertUserLiveTimeOut")
            if UIViewController.responds(to: selector) {
                UIViewController.perform(selector)
            }
            EngineEventCenter.shared.notifyUIEvent(key: .TUIRoomKitService_DismissConferenceViewController, param: [:])
            engineManager.destroyEngineManager()
            return
        }
#endif
        engineManager.destroyEngineManager()
        viewResponder?.showAlertWithAutoConfirm(title: .destroyAlertText, message: nil, sureTitle: .alertOkText, declineTitle: nil, sureBlock: {
            EngineEventCenter.shared.notifyUIEvent(key: .TUIRoomKitService_DismissConferenceViewController, param: [:])
        }, declineBlock: nil, autoConfirmSeconds: 5)
    }
    
    private func handleKickedOutOfRoom() {
        engineManager.destroyEngineManager()
        viewResponder?.showAlertWithAutoConfirm(title: .kickOffTitleText, message: nil, sureTitle: .alertOkText, declineTitle: nil , sureBlock: {
            EngineEventCenter.shared.notifyUIEvent(key: .TUIRoomKitService_DismissConferenceViewController, param: [:])
        }, declineBlock: nil, autoConfirmSeconds: 5)
        conferenceStore.dispatch(action: RoomResponseActions.onExitSuccess())
    }
    
    private func handleAllUserMicrophoneDisableChanged(isDisable: Bool) {
        if isDisable {
            RoomRouter.makeToastInCenter(toast: .allMuteAudioText, duration: 1.5)
        } else {
            RoomRouter.makeToastInCenter(toast: .allUnMuteAudioText, duration: 1.5)
        }
    }
    
    private func handleAllUserCameraDisableChanged(isDisable: Bool) {
        if isDisable {
            RoomRouter.makeToastInCenter(toast: .allMuteVideoText, duration: 1.5)
        } else {
            RoomRouter.makeToastInCenter(toast: .allUnMuteVideoText, duration: 1.5)
        }
    }
    
    private func handleReceivedRequest(request: TUIRequest) {
        switch request.requestAction {
        case .openRemoteCamera:
            handleOpenCameraRequest(request: request)
        case .openRemoteMicrophone:
            handleOpenMicrophoneRequest(request: request)
        case .invalidAction:
            break
        case .remoteUserOnSeat:
            handleOnSeatRequest(request: request)
        default: break
        }
    }
    
    private func handleOpenCameraRequest(request: TUIRequest) {
        guard !isShownOpenCameraInviteAlert else { return }
        guard let userInfo = store.attendeeList.first(where: { $0.userId == request.userId }) else { return }
        let nameText: String = userInfo.userRole == .roomOwner ? .hostText : .administratorText
        let title = localizedReplace(.inviteTurnOnVideoText, replace: nameText)
        viewResponder?.showAlert(title: title, message: nil, sureTitle: .agreeText, declineTitle: .declineText, sureBlock: { [weak self] in
            guard let self = self else { return }
            self.isShownOpenCameraInviteAlert = false
            self.agreeOpenLocalCamera(request: request)
        }, declineBlock: { [weak self] in
            guard let self = self else { return }
            self.isShownOpenCameraInviteAlert = false
            self.engineManager.responseRemoteRequest(request.requestId, agree: false)
        })
        isShownOpenCameraInviteAlert = true
    }
    
    private func agreeOpenLocalCamera(request: TUIRequest) {
        engineManager.setLocalVideoView(nil)
        if RoomCommon.checkAuthorCamaraStatusIsDenied() {
            engineManager.responseRemoteRequest(request.requestId, agree: true)
        } else {
            RoomCommon.cameraStateActionWithPopCompletion { [weak self] granted in
                guard let self = self else { return }
                self.engineManager.responseRemoteRequest(request.requestId, agree: granted)
            }
        }
    }
    
    private func handleOpenMicrophoneRequest(request: TUIRequest) {
        guard !isShownOpenMicrophoneInviteAlert else { return }
        guard let userInfo = store.attendeeList.first(where: { $0.userId == request.userId }) else { return }
        let nameText: String = userInfo.userRole == .roomOwner ? .hostText : .administratorText
        let title = localizedReplace(.inviteTurnOnAudioText, replace: nameText)
        viewResponder?.showAlert(title: title, message: nil, sureTitle: .agreeText, declineTitle: .declineText, sureBlock: { [weak self] in
            guard let self = self else { return }
            self.isShownOpenMicrophoneInviteAlert = false
            self.agreeOpenLocalMic(request: request)
        }, declineBlock: { [weak self] in
            guard let self = self else { return }
            self.isShownOpenMicrophoneInviteAlert = false
            self.engineManager.responseRemoteRequest(request.requestId, agree: false)
        })
        isShownOpenMicrophoneInviteAlert = true
    }
    
    private func agreeOpenLocalMic(request: TUIRequest) {
        if RoomCommon.checkAuthorMicStatusIsDenied() {
            self.engineManager.responseRemoteRequest(request.requestId, agree: true)
        } else {
            RoomCommon.micStateActionWithPopCompletion { [weak self] granted in
                guard let self = self else { return }
                self.engineManager.responseRemoteRequest(request.requestId, agree: granted)
            }
        }
    }
    
    private func handleOnSeatRequest(request: TUIRequest) {
        guard roomInfo.isSeatEnabled && !isShownTakeSeatInviteAlert else { return }
        guard let userInfo = store.attendeeList.first(where: { $0.userId == request.userId }) else { return }
        let nameText: String = userInfo.userRole == .roomOwner ? .hostText : .administratorText
        let title = localizedReplace(.inviteSpeakOnStageTitle, replace: nameText)
        viewResponder?.showAlert(title: title, message: .inviteSpeakOnStageMessage, sureTitle: .agreeSeatText, declineTitle: .declineText, sureBlock: { [weak self] in
            guard let self = self else { return }
            self.isShownTakeSeatInviteAlert = false
            self.agreeOnSeatRequest(requestId: request.requestId)
        }, declineBlock: { [weak self] in
            guard let self = self else { return }
            self.isShownTakeSeatInviteAlert = false
            self.disagreeOnSeatRequest(requestId: request.requestId)
        })
        isShownTakeSeatInviteAlert = true
    }
    
    private func agreeOnSeatRequest(requestId: String) {
        engineManager.responseRemoteRequest(requestId, agree: true) {
        } onError: { [weak self] code, message in
            guard let self = self else { return }
            switch code {
            case .failed:
                self.viewResponder?.makeToast(text: .goOnStageTimedOutText)
            case .allSeatOccupied:
                self.viewResponder?.makeToast(text: .onStageNumberReachedLimitText)
            default: break
            }
        }
    }
    
    private func disagreeOnSeatRequest(requestId: String) {
        engineManager.responseRemoteRequest(requestId, agree: false) {
        } onError: { code, message in
            debugPrint("responseRemoteRequest:code:\(code),message:\(message)")
        }
    }
    
    private func handleKickedOffLine() {
        viewResponder?.showAlertWithAutoConfirm(title: .kieckedOffLineText, message: nil, sureTitle: .alertOkText, declineTitle: nil, sureBlock: {
            EngineEventCenter.shared.notifyUIEvent(key: .TUIRoomKitService_DismissConferenceViewController, param: [:])
        }, declineBlock: nil, autoConfirmSeconds: 5)
        conferenceStore.dispatch(action: RoomResponseActions.onExitSuccess())
    }
    
    private func handleStartRoom(roomInfo: TUIRoomInfo) {
        viewResponder?.updateRoomInfo(roomInfo: roomInfo)
    }
    
    private func handleJoinRoom(roomInfo: TUIRoomInfo) {
        if roomInfo.isSeatEnabled, store.isShownRaiseHandNotice {
            viewResponder?.showRaiseHandNoticeView()
        }
        viewResponder?.updateRoomInfo(roomInfo: roomInfo)
    }
    
    private func handleUserVideoStateChanged(userId: String, streamType: TUIVideoStreamType, hasVideo: Bool, reason: TUIChangeReason) {
        guard streamType == .screenStream, !hasVideo, reason == .byAdmin else { return }
        RoomRouter.presentAlert(title: .screenSharingHasStoppedAlertTitle, message: .screenSharingHasStoppedAlertMessage, sureTitle: .iSee, declineTitle: nil, sureBlock: nil, declineBlock: nil)
    }
}

extension ConferenceMainViewModel: ConferenceMainViewFactory {
    func makeConferencePasswordView() -> ConferencePasswordView {
        let passwordView = ConferencePasswordView()
        passwordView.isHidden = true
        passwordView.viewModel = self
        return passwordView
    }
    
    func makeTopView() -> TopView {
        let viewModel = TopViewModel()
        let topView = TopView(viewModel: viewModel)
        topView.backgroundColor = UIColor(0x0F1014)
        return topView
    }
    
    func makeBottomView() -> BottomView {
        let viewModel = BottomViewModel()
        let bottomView = BottomView(viewModel: viewModel)
        return bottomView
    }
    
    func makeVideoSeatView() -> UIView {
        let videoSeatView = ConferenceStreamContainer()
        videoSeatView.backgroundColor = UIColor(0x0F1014)
        return videoSeatView
    }
    
    func makeRaiseHandNoticeView() -> UIView {
        let raiseHandNoticeView = RaiseHandNoticeView()
        raiseHandNoticeView.isHidden = true
        return raiseHandNoticeView
    }
    
    func makeLocalAudioView() -> LocalAudioView {
        return LocalAudioView()
    }
    
    func makeWaterMarkLayer() -> WaterMarkLayer {
        let layer = WaterMarkLayer()
        layer.backgroundColor = UIColor.clear.cgColor
        layer.anchorPoint = CGPointZero
        layer.text = getWaterMarkText()
        layer.lineStyle = .multiLine
        layer.cornerRadius = 16
        return layer
    }
    
    func makeFloatChatButton() -> FloatChatButton {
        let floatchatButton = FloatChatButton()
        floatchatButton.isHidden = !store.shouldShowFloatChatView
        if store.isEnteredRoom {
            floatchatButton.updateRoomId(roomId: store.roomInfo.roomId)
        }
        return floatchatButton
    }
    
    func makeFloatChatDisplayView() -> FloatChatDisplayView {
        let view = FloatChatDisplayView()
        view.isHidden = !store.shouldShowFloatChatView
        view.delegate = self
        return view
    }
    
    func makeRaiseHandApplicationNotificationView() -> RaiseHandApplicationNotificationView {
        let viewModel = RaiseHandApplicationNotificationViewModel()
        let notificationView = RaiseHandApplicationNotificationView(viewModel: viewModel)
        return notificationView
    }
    
    private func getWaterMarkText() -> String {
        let customizeText = ConferenceSession.sharedInstance.implementation.waterMarkText
        if !customizeText.isEmpty {
            return customizeText
        }
        if !store.isEnteredRoom {
            return ""
        }
        var defaultText = currentUser.userId
        let userName = engineManager.getSelfInfo().userName
        if !userName.isEmpty {
            defaultText = defaultText + "(\(userName))"
        }
        return defaultText
    }
}

extension ConferenceMainViewModel: RoomKitUIEventResponder {
    func onNotifyUIEvent(key: EngineEventCenter.RoomUIEvent, Object: Any?, info: [AnyHashable : Any]?) {
        switch key{
        case .TUIRoomKitService_CurrentUserRoleChanged:
            guard let userRole = info?["userRole"] as? TUIRole else { return }
            handleSelfRoleChanged(userRole: userRole)
        case .TUIRoomKitService_CurrentUserMuteMessage:
            guard let isMute = info?["isMute"] as? Bool else { return }
            viewResponder?.makeToast(text: isMute ? .messageTurnedOffText : .messageTurnedOnText)
        case .TUIRoomKitService_ChangeToolBarHiddenState:
            viewResponder?.changeToolBarHiddenState()
        case .TUIRoomKitService_SetToolBarDelayHidden:
            guard let isDelay = info?["isDelay"] as? Bool else { return }
            viewResponder?.setToolBarDelayHidden(isDelay: isDelay)
        case .TUIRoomKitService_ShowExitRoomView:
            viewResponder?.showExitRoomView()
        case .TUIRoomKitService_DismissConferenceViewController:
            conferenceStore.dispatch(action: ConferenceInvitationActions.clearInvitationList())
            conferenceStore.dispatch(action: RoomActions.clearRoomState())
        default: break
        }
    }
    
    private func handleSelfRoleChanged(userRole: TUIRole) {
        switch userRole {
        case .roomOwner:
            viewResponder?.makeToast(text: .haveBecomeMasterText)
        case .administrator:
            viewResponder?.makeToast(text: .haveBecomeAdministratorText)
        case .generalUser:
            if selfRole == .administrator {
                viewResponder?.makeToast(text: .revokedAdministratorText)
            }
        default: break
        }
        selfRole = userRole
    }
}

extension ConferenceMainViewModel: FloatChatDisplayViewDelegate {
    func getTheLatestUserName(userId: String) -> String {
        return store.attendeeList.first(where: { $0.userId == userId })?.userName ?? ""
    }
}

private extension String {
    static var kickOffTitleText: String {
        localized("You were removed by the host.")
    }
    static var destroyAlertText: String {
        localized("The conference was closed.")
    }
    static var inviteTurnOnAudioText: String {
        localized("xx invites you to turn on the microphone")
    }
    static var inviteTurnOnVideoText: String {
        localized("xx invites you to turn on the camera")
    }
    static var inviteSpeakOnStageTitle: String {
        localized("xx invites you to speak on stage")
    }
    static var inviteSpeakOnStageMessage: String {
        localized("You can turn on the camera and unmute it once you are on stage")
    }
    static var messageTurnedOffText: String {
        localized("You were muted message by the host.")
    }
    static var messageTurnedOnText: String {
        localized("You were unmuted message by the host.")
    }
    static var haveBecomeMasterText: String {
        localized("You are now a host")
    }
    static var haveBecomeAdministratorText: String {
        localized("You have become a conference admin")
    }
    static var kickedOffLineText: String {
        localized("You are already logged in elsewhere")
    }
    static var alertOkText: String {
        localized("OK")
    }
    static var declineText: String {
        localized("Decline")
    }
    static var agreeText: String {
        localized("Agree")
    }
    static var agreeSeatText: String {
        localized("Approve")
    }
    static var allMuteAudioText: String {
        localized("All audios disabled")
    }
    static var allMuteVideoText: String {
        localized("All videos disabled")
    }
    static var allUnMuteAudioText: String {
        localized("All audios enabled")
    }
    static var allUnMuteVideoText: String {
        localized("All videos enabled")
    }
    static var kickedOffSeat: String {
        localized("You have been invited by the host to step down, please raise your hand if you need to speak")
    }
    static var hostText: String {
        localized("Host")
    }
    static var administratorText: String {
        localized("Administrator")
    }
    static var revokedAdministratorText: String {
        localized("Your conference admin status has been revoked")
    }
    static var onStageNumberReachedLimitText: String {
        localized("The stage is full, please contact the host")
    }
    static var goOnStageTimedOutText: String {
        localized("Failed to go on stage, invitation has timed out")
    }
    static var kieckedOffLineText: String {
        localized("You are already logged in elsewhere")
    }
    static var logoutText: String {
        localized("You are logged out")
    }
    static let wrongPasswordText = localized("Wrong password")
    static let iSee = localized("I see")
    static let screenSharingHasStoppedAlertTitle = localized("Your screen sharing has stopped")
    static let screenSharingHasStoppedAlertMessage = localized("Your screen sharing has stopped, Now only the host/admin can share the screen")
}
