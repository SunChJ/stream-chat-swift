//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatTestTools
@testable import StreamChatUI
import XCTest

@available(iOS 13.0, *)
class ChatChannelListVCComponent_Tests: XCTestCase {
    var chatChannelList: ChatChannelList!
    var mockedChannelListController: ChatChannelListController_Mock<NoExtraData>!

    override func setUp() {
        super.setUp()
        mockedChannelListController = ChatChannelListController_Mock.mock()
        chatChannelList = ChatChannelListVC._ChatChannelList(controller: mockedChannelListController)
    }

    func test_chatChannelList_isPopulated() {
        let channel = ChatChannel.mock(
            cid: .unique,
            name: "Channel 1",
            imageURL: TestImages.yoda.url,
            lastMessageAt: .init(timeIntervalSince1970: 1_611_951_526_000)
        )
        let channelWithOnlineIndicator = ChatChannel.mockDMChannel(
            lastMessageAt: .init(timeIntervalSince1970: 1_611_951_527_000),
            members: [.mock(id: .unique, name: "Darth Vader", imageURL: TestImages.vader.url, isOnline: true)]
        )
        let channelWithLongTextAndUnreadCount = ChatChannel.mock(
            cid: .init(type: .messaging, id: "test_channel3"),
            name: "This is a channel with a big name. Really big.",
            imageURL: TestImages.yoda.url,
            lastMessageAt: .init(timeIntervalSince1970: 1_611_951_528_000),
            unreadCount: .mock(messages: 4),
            latestMessages: [
                ChatMessage.mock(
                    id: "1", text: "This is a long message. How the UI will adjust?", author: .mock(id: "Vader2")
                )
            ]
        )
        let channelWithMultipleMessages = ChatChannel.mock(
            cid: .init(type: .messaging, id: "test_channel4"),
            name: "Channel 4",
            imageURL: TestImages.vader.url,
            lastMessageAt: .init(timeIntervalSince1970: 1_611_951_529_000),
            latestMessages: [
                ChatMessage.mock(id: "2", text: "Hello", author: .mock(id: "Vader")),
                ChatMessage.mock(id: "1", text: "Hello2", author: .mock(id: "Vader2"))
            ]
        )
        mockedChannelListController.simulate(
            channels: [
                channel,
                channelWithOnlineIndicator,
                channelWithLongTextAndUnreadCount,
                channelWithMultipleMessages
            ],
            changes: []
        )
        
        AssertSnaphot(chatChannelList)
    }
}
