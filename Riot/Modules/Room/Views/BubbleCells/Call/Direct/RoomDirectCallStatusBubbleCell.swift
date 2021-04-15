// 
// Copyright 2020 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit

/// The number of milliseconds in one second.
private let MSEC_PER_SEC: TimeInterval = 1000

@objcMembers
class RoomDirectCallStatusBubbleCell: RoomBaseCallBubbleCell {
    
    /// Action identifier used when the user pressed "Call back" button for a declined call.
    /// The `userInfo` dictionary contains an `MXEvent` object under the `kMXKRoomBubbleCellEventKey` key, representing the invite event of the declined call.
    static let callBackAction: String = "RoomDirectCallStatusBubbleCell.CallBack"
    
    /// Action identifier used when the user pressed "Answer" button for an incoming call.
    /// The `userInfo` dictionary contains an `MXEvent` object under the `kMXKRoomBubbleCellEventKey` key, representing the invite event of the call.
    static let answerAction: String = "RoomDirectCallStatusBubbleCell.Answer"
    
    /// Action identifier used when the user pressed "Decline" button for an incoming call.
    /// The `userInfo` dictionary contains an `MXEvent` object under the `kMXKRoomBubbleCellEventKey` key, representing the invite event of the call.
    static let declineAction: String = "RoomDirectCallStatusBubbleCell.Decline"
    
    private var callDurationString: String = ""
    private var isVideoCall: Bool = false
    private var isIncoming: Bool = false
    private var callInviteEvent: MXEvent?
    private var viewState: ViewState = .unknown {
        didSet {
            updateBottomContentView()
        }
    }
    
    private enum ViewState {
        case unknown
        case ringing
        case active
        case declined
        case missed
        case ended
        case failed
    }
    
    private static var callDurationFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }
    
    private func updateBottomContentView() {
        bottomContentView = bottomView(for: viewState)
    }
    
    private var callTypeIcon: UIImage {
        if isVideoCall {
            return Asset.Images.callVideoIcon.image
        } else {
            return Asset.Images.voiceCallHangonIcon.image
        }
    }
    
    private var actionUserInfo: [AnyHashable: Any]? {
        if let event = callInviteEvent {
            return [kMXKRoomBubbleCellEventKey: event]
        }
        return nil
    }
    
    private func bottomView(for state: ViewState) -> UIView? {
        switch state {
        case .unknown:
            return nil
        case .ringing:
            let view = HorizontalButtonsContainerView.loadFromNib()
            
            view.firstButton.style = .negative
            view.firstButton.setTitle(VectorL10n.eventFormatterCallDecline, for: .normal)
            view.firstButton.setImage(Asset.Images.voiceCallHangupIcon.image, for: .normal)
            view.firstButton.removeTarget(nil, action: nil, for: .touchUpInside)
            view.firstButton.addTarget(self, action: #selector(declineCallAction(_:)), for: .touchUpInside)
            
            view.secondButton.style = .positive
            view.secondButton.setTitle(VectorL10n.eventFormatterCallAnswer, for: .normal)
            view.secondButton.setImage(callTypeIcon, for: .normal)
            view.secondButton.removeTarget(nil, action: nil, for: .touchUpInside)
            view.secondButton.addTarget(self, action: #selector(answerCallAction(_:)), for: .touchUpInside)
            
            return view
        case .active:
            return nil
        case .declined:
            let view = HorizontalButtonsContainerView.loadFromNib()
            view.secondButton.isHidden = true
            
            view.firstButton.style = .positive
            view.firstButton.setTitle(VectorL10n.eventFormatterCallBack, for: .normal)
            view.firstButton.setImage(callTypeIcon, for: .normal)
            view.firstButton.removeTarget(nil, action: nil, for: .touchUpInside)
            view.firstButton.addTarget(self, action: #selector(callBackAction(_:)), for: .touchUpInside)
            
            return view
        case .missed:
            let view = HorizontalButtonsContainerView.loadFromNib()
            view.secondButton.isHidden = true
            
            view.firstButton.style = .positive
            view.firstButton.setTitle(VectorL10n.eventFormatterCallBack, for: .normal)
            view.firstButton.setImage(callTypeIcon, for: .normal)
            view.firstButton.removeTarget(nil, action: nil, for: .touchUpInside)
            view.firstButton.addTarget(self, action: #selector(callBackAction(_:)), for: .touchUpInside)
            
            return view
        case .ended:
            return nil
        case .failed:
            let view = HorizontalButtonsContainerView.loadFromNib()
            view.secondButton.isHidden = true
            
            view.firstButton.style = .positive
            view.firstButton.setTitle(VectorL10n.eventFormatterCallRetry, for: .normal)
            view.firstButton.setImage(callTypeIcon, for: .normal)
            view.firstButton.removeTarget(nil, action: nil, for: .touchUpInside)
            view.firstButton.addTarget(self, action: #selector(callBackAction(_:)), for: .touchUpInside)
            
            return view
        }
    }
    
    private func configure(withCall call: MXCall) {
        switch call.state {
        case .fledgling,
            .waitLocalMedia,
            .createOffer,
            .inviteSent,
            .connecting:
            viewState = .active
            if call.isIncoming {
                statusText = VectorL10n.eventFormatterCallYouCurrentlyIn
            } else {
                statusText = VectorL10n.eventFormatterCallYouStarted
            }
        case .createAnswer,
             .connected,
             .onHold,
             .remotelyOnHold:
            viewState = .active
            statusText = VectorL10n.eventFormatterCallYouCurrentlyIn
        case .ringing:
            if call.isIncoming {
                viewState = .ringing
                statusText = nil
            } else {
                viewState = .active
                statusText = VectorL10n.eventFormatterCallYouCurrentlyIn
            }
        case .ended:
            switch call.endReason {
            case .unknown,
                 .hangup,
                 .hangupElsewhere,
                 .remoteHangup,
                 .answeredElseWhere:
                viewState = .ended
                statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
            case .missed:
                if call.isIncoming {
                    viewState = .missed
                    statusText = VectorL10n.eventFormatterCallYouMissed
                } else {
                    statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
                }
            case .busy:
                configureForRejectedCall(call: call)
            @unknown default:
                viewState = .ended
                statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
            }
        case .inviteExpired,
             .answeredElseWhere:
            viewState = .ended
            statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
        @unknown default:
            viewState = .ended
            statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
        }
    }
    
    private func configureForRejectedCall(withEvent event: MXEvent? = nil, call: MXCall? = nil, bubbleCellData: RoomBubbleCellData? = nil) {
        
        let isMyReject: Bool
        
        if let call = call, call.isIncoming {
            isMyReject = true
        } else if let event = event, let bubbleCellData = bubbleCellData, event.sender == bubbleCellData.mxSession.myUserId {
            isMyReject = true
        } else {
            isMyReject = false
        }
        
        if isMyReject {
            viewState = .declined
            statusText = VectorL10n.eventFormatterCallYouDeclined
        } else {
            viewState = .ended
            statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
        }
    }
    
    private func configureForHangupCall(withEvent event: MXEvent) {
        guard let hangupEventContent = MXCallHangupEventContent(fromJSON: event.content) else {
            viewState = .ended
            statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
            return
        }
        
        switch hangupEventContent.reasonType {
        case .userHangup:
            viewState = .ended
            statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
        default:
            viewState = .failed
            statusText = VectorL10n.eventFormatterCallConnectionFailed
        }
    }
    
    private func configureForUnansweredCall() {
        if isIncoming {
            //  missed call
            viewState = .missed
            statusText = VectorL10n.eventFormatterCallYouMissed
        } else {
            //  outgoing unanswered call
            viewState = .ended
            statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
        }
    }
    
    //  MARK: - Actions
    
    @objc
    private func callBackAction(_ sender: CallTileActionButton) {
        self.delegate?.cell(self,
                            didRecognizeAction: Self.callBackAction,
                            userInfo: actionUserInfo)
    }
    
    @objc
    private func declineCallAction(_ sender: CallTileActionButton) {
        self.delegate?.cell(self,
                            didRecognizeAction: Self.declineAction,
                            userInfo: actionUserInfo)
    }
    
    @objc
    private func answerCallAction(_ sender: CallTileActionButton) {
        self.delegate?.cell(self,
                            didRecognizeAction: Self.answerAction,
                            userInfo: actionUserInfo)
    }
    
    //  MARK: - MXKCellRendering
    
    override func render(_ cellData: MXKCellData!) {
        super.render(cellData)
        
        viewState = .unknown
        
        guard let bubbleCellData = cellData as? RoomBubbleCellData else {
            return
        }
        
        let events = bubbleCellData.allLinkedEvents()
        
        guard let inviteEvent = events.first(where: { $0.eventType == .callInvite }) else {
            return
        }
        
        if bubbleCellData.senderId == bubbleCellData.mxSession.myUserId {
            //  event sent by my user, no means in displaying our own avatar and display name
            if let directUserId = bubbleCellData.mxSession.directUserId(inRoom: bubbleCellData.roomId) {
                let user = bubbleCellData.mxSession.user(withUserId: directUserId)
                
                let placeholder = AvatarGenerator.generateAvatar(forMatrixItem: directUserId,
                                                                 withDisplayName: user?.displayname)
                
                innerContentView.avatarImageView.setImageURI(user?.avatarUrl,
                                            withType: nil,
                                            andImageOrientation: .up,
                                            toFitViewSize: innerContentView.avatarImageView.frame.size,
                                            with: MXThumbnailingMethodCrop,
                                            previewImage: placeholder,
                                            mediaManager: bubbleCellData.mxSession.mediaManager)
                innerContentView.avatarImageView.defaultBackgroundColor = .clear
                
                innerContentView.callerNameLabel.text = user?.displayname
            }
        } else {
            innerContentView.avatarImageView.setImageURI(bubbleCellData.senderAvatarUrl,
                                        withType: nil,
                                        andImageOrientation: .up,
                                        toFitViewSize: innerContentView.avatarImageView.frame.size,
                                        with: MXThumbnailingMethodCrop,
                                        previewImage: bubbleCellData.senderAvatarPlaceholder,
                                        mediaManager: bubbleCellData.mxSession.mediaManager)
            innerContentView.avatarImageView.defaultBackgroundColor = .clear
            
            innerContentView.callerNameLabel.text = bubbleCellData.senderDisplayName
        }
        
        guard let callInviteEventContent = MXCallInviteEventContent(fromJSON: inviteEvent.content) else {
            return
        }
        isVideoCall = callInviteEventContent.isVideoCall()
        callDurationString = readableCallDuration(from: events)
        isIncoming = inviteEvent.sender != bubbleCellData.mxSession.myUserId
        callInviteEvent = inviteEvent
        innerContentView.callIconView.image = self.callTypeIcon
        innerContentView.callTypeLabel.text = isVideoCall ?
            VectorL10n.eventFormatterCallVideo :
            VectorL10n.eventFormatterCallVoice
        
        let callId = callInviteEventContent.callId
        guard let call = bubbleCellData.mxSession.callManager.call(withCallId: callId) else {
            
            //  check events include a reject event
            if let rejectEvent = events.first(where: { $0.eventType == .callReject }) {
                configureForRejectedCall(withEvent: rejectEvent, bubbleCellData: bubbleCellData)
                return
            }
            
            //  check events include an answer event
            if !events.contains(where: { $0.eventType == .callAnswer }) {
                configureForUnansweredCall()
                return
            }
            
            //  check events include a hangup event
            if let hangupEvent = events.first(where: { $0.eventType == .callHangup }) {
                configureForHangupCall(withEvent: hangupEvent)
                return
            }
            
            //  there is no reject or hangup event, we can just say this call has ended
            viewState = .ended
            statusText = VectorL10n.eventFormatterCallHasEnded(callDurationString)
            return
        }
        
        configure(withCall: call)
    }
    
    private func callDuration(from events: [MXEvent]) -> TimeInterval {
        guard let startDate = events.first(where: { $0.eventType == .callAnswer })?.originServerTs else {
            //  never started
            return 0
        }
        guard let endDate = events.first(where: { $0.eventType == .callHangup })?.originServerTs
                ?? events.first(where: { $0.eventType == .callReject })?.originServerTs else {
            //  not ended yet, compute the diff from now
            return (NSTimeIntervalSince1970 - TimeInterval(startDate))/MSEC_PER_SEC
        }
        
        //  ended, compute the diff between two dates
        return TimeInterval(endDate - startDate)/MSEC_PER_SEC
    }
    
    private func readableCallDuration(from events: [MXEvent]) -> String {
        let duration = callDuration(from: events)
        
        if duration <= 0 {
            return ""
        }
        
        return RoomDirectCallStatusBubbleCell.callDurationFormatter.string(from: duration) ?? ""
    }
    
}
