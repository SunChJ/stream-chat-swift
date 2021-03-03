//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit
import MagazineLayout

public typealias СhatMessageCollectionViewCell = _СhatMessageCollectionViewCell<NoExtraData>

open class _СhatMessageCollectionViewCell<ExtraData: ExtraDataTypes>: _CollectionViewCell, UIConfigProvider {
    class var reuseId: String { String(describing: self) }

    public var message: _ChatMessageGroupPart<ExtraData>? {
        didSet { updateContentIfNeeded() }
    }

    // MARK: - Subviews

    public private(set) lazy var messageView = uiConfig.messageList.messageContentView.init().withoutAutoresizingMaskConstraints

    // MARK: - Lifecycle

    override open func setUpLayout() {
        contentView.addSubview(messageView)

        NSLayoutConstraint.activate([
            messageView.topAnchor.pin(equalTo: contentView.topAnchor),
            messageView.bottomAnchor.pin(equalTo: contentView.bottomAnchor),
            messageView.widthAnchor.pin(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)
        ])
    }

    override open func updateContent() {
        messageView.message = message
    }

    // MARK: - Overrides

    override open func prepareForReuse() {
        super.prepareForReuse()

        message = nil
    }

    override open func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
//        guard let attributes = layoutAttributes as? MagazineLayoutCollectionViewLayoutAttributes else {
//            assertionFailure("`layoutAttributes` must be an instance of `MagazineLayoutCollectionViewLayoutAttributes`")
//            return super.preferredLayoutAttributesFitting(layoutAttributes)
//        }
        let shouldVerticallySelfSize = true
        // In some cases, `contentView`'s required width and height constraints
        // (created from its auto-resizing mask) will not have the correct constants before invoking
        // `systemLayoutSizeFitting(...)`, causing the cell to size incorrectly. This seems to be a
        // UIKit bug.
        // https://openradar.appspot.com/radar?id=5025850143539200
        // The issue seems most common when the collection view's bounds change (on rotation).
        // We correct for this by updating `contentView.bounds`, which updates the constants used by the
        // width and height constraints created by the `contentView`'s auto-resizing mask.
        if contentView.bounds.width != layoutAttributes.size.width {
            contentView.bounds.size.width = layoutAttributes.size.width
        }
        if
            !shouldVerticallySelfSize &&
                contentView.bounds.height != layoutAttributes.size.height
        {
            contentView.bounds.size.height = layoutAttributes.size.height
        }
        let size = super.systemLayoutSizeFitting(
            layoutAttributes.size,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        layoutAttributes.size = size
        return layoutAttributes
        
    }
}

private var prototypes = [String: UICollectionViewCell]()

class СhatIncomingMessageCollectionViewCell<ExtraData: ExtraDataTypes>: _СhatMessageCollectionViewCell<ExtraData> {
    override func setUpLayout() {
        super.setUpLayout()
        messageView.leadingAnchor.pin(equalTo: contentView.layoutMarginsGuide.leadingAnchor).isActive = true
    }
}

class СhatOutgoingMessageCollectionViewCell<ExtraData: ExtraDataTypes>: _СhatMessageCollectionViewCell<ExtraData> {
    override func setUpLayout() {
        super.setUpLayout()
        messageView.trailingAnchor.pin(equalTo: contentView.layoutMarginsGuide.trailingAnchor).isActive = true
    }
}

public typealias СhatMessageAttachmentCollectionViewCell = _СhatMessageAttachmentCollectionViewCell<NoExtraData>

open class _СhatMessageAttachmentCollectionViewCell<ExtraData: ExtraDataTypes>: _СhatMessageCollectionViewCell<ExtraData> {
    private var _messageAttachmentContentView: _ChatMessageAttachmentContentView<ExtraData>?
    
    override public var messageView: _ChatMessageContentView<ExtraData> {
        if let messageContentView = _messageAttachmentContentView {
            return messageContentView
        } else {
            _messageAttachmentContentView = uiConfig
                .messageList
                .messageAttachmentContentView
                .init()
                .withoutAutoresizingMaskConstraints
            return _messageAttachmentContentView!
        }
    }
}

// swiftlint:disable:next colon
class СhatIncomingMessageAttachmentCollectionViewCell<ExtraData: ExtraDataTypes>:
    _СhatMessageAttachmentCollectionViewCell<ExtraData> {
    override func setUpLayout() {
        super.setUpLayout()
        messageView.leadingAnchor.pin(equalTo: contentView.layoutMarginsGuide.leadingAnchor).isActive = true
    }
}

// swiftlint:disable:next colon
class СhatOutgoingMessageAttachmentCollectionViewCell<ExtraData: ExtraDataTypes>:
    _СhatMessageAttachmentCollectionViewCell<ExtraData> {
    override func setUpLayout() {
        super.setUpLayout()
        messageView.trailingAnchor.pin(equalTo: contentView.layoutMarginsGuide.trailingAnchor).isActive = true
    }
}
