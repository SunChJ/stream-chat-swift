//
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChat
import StreamChatUI

final class MessengerChatChannelListViewController: ChatChannelListVC {
    init() {
        super.init(nibName: nil, bundle: nil)

        let channelListController = ChatClient
            .shared
            .channelListController(
                query: ChannelListQuery(
                    filter: .containMembers(
                        userIds: [ChatClient.shared.currentUserId!]
                    )
                )
            )
        self.controller = channelListController
    }

    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
}

