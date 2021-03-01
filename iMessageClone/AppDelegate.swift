//
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChat
import StreamChatUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {        
        UIConfig.default.channelList.channelListItemView = iMessageChatChannelListItemView.self

        UIConfig.default.navigation.channelListRouter = iMessageChatChannelListRouter.self
        UIConfig.default.images.newChat = UIImage(systemName: "square.and.pencil")!
        UIConfig.default.messageComposer.messageComposerView = iMessageChatMessageComposerView.self
        UIConfig.default.messageList.messageContentView = iMessageChatMessageContentView.self
        UIConfig.default.messageList.outgoingMessageCell = iMessageСhatOutgoingMessageCollectionViewCell.self
        UIConfig.default.messageList.incomingMessageCell = iMessageСhatOutgoingMessageCollectionViewCell.self
        UIConfig.default.messageComposer.messageComposerViewController = iMessageChatComposerViewController.self

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = UINavigationController(
            rootViewController: iMessageChatChannelListViewController()
        )

        return true
    }
}

extension ChatClient {
    /// The singleton instance of `ChatClient`
    static let shared: ChatClient = {
        let config = ChatClientConfig(apiKey: APIKey("q95x9hkbyd6p"))
        return ChatClient(config: config, tokenProvider: .static("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiY2lsdmlhIn0.jHi2vjKoF02P9lOog0kDVhsIrGFjuWJqZelX5capR30"))
    }()
}