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
        // Override point for customization after application launch.
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

