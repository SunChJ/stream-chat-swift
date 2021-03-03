//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import MagazineLayout
import UIKit

public typealias ChatMessageListCollectionViewLayout = MagazineLayout

/// Custom Table View like layout that position item at index path 0-0 on bottom of the list.
///
/// Unlike `UICollectionViewFlowLayout` we ignore some invalidation calls and persist items attributes between updates.
/// This resolves problem when on item reload layout would change content offset and user ends up on completely different item.
/// Layout intended for batch updates and right now I have no idea how it will react to `collectionView.reloadData()`.
open class _ChatMessageListCollectionViewLayout: UICollectionViewLayout {
    open class InvalidationContext: UICollectionViewLayoutInvalidationContext {
        var updatedAttributes: UICollectionViewLayoutAttributes?
        
        convenience init(updatedAttributes: UICollectionViewLayoutAttributes) {
            self.init()
            self.updatedAttributes = updatedAttributes
        }
    }
    
    open override class var invalidationContextClass: AnyClass { InvalidationContext.self }
    
    open var cachedAttributes = [UICollectionViewLayoutAttributes]()
    open var appearingItems = Set<UICollectionViewLayoutAttributes>()
    
    /// IndexPath for most recent message
    public let mostRecentItem = IndexPath(item: 0, section: 0)

    /// With better approximation you are getting better performance
    open var estimatedItemHeight: CGFloat = 200
    /// Vertical spacing between items
    open var spacing: CGFloat = 4
    
    open var maxY: CGFloat = 0
    open var width: CGFloat { inflightWidth ?? collectionView?.bounds.width ?? 0 }
    open var inflightWidth: CGFloat?

    override open var collectionViewContentSize: CGSize {
        CGSize(width: width, height: maxY)
    }

    // MARK: - Initialization

    override public required init() {
        super.init()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Layout invalidation
    
    open override func invalidateLayout() {
        super.invalidateLayout()
        cachedAttributes.removeAll()
    }

    override open func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        if let attributes = (context as? InvalidationContext)?.updatedAttributes {
            cachedAttributes[attributes.indexPath.item].size = CGSize(width: width, height: attributes.size.height)
        }
        super.invalidateLayout(with: context)
    }

    override open func shouldInvalidateLayout(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> Bool {
        preferredAttributes != originalAttributes
    }
    
    open override func prepare(forAnimatedBoundsChange oldBounds: CGRect) {
        super.prepare(forAnimatedBoundsChange: oldBounds)
        inflightWidth = collectionView?.bounds.width
    }
    
    open override func finalizeAnimatedBoundsChange() {
        super.finalizeAnimatedBoundsChange()
        inflightWidth = nil
    }
    
    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
//        false
        collectionView.map { $0.bounds.size.width != newBounds.width } ?? true
    }
    
    open override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)

        if let collectionView = collectionView {
            let all = (0..<collectionView.numberOfItems(inSection: 0))
                .map { IndexPath(item: $0, section: 0)}
            context.invalidateItems(at: all)
        }

        return context
    }

    override open func invalidationContext(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutInvalidationContext {
        let invalidationContext = super.invalidationContext(
            forPreferredLayoutAttributes: preferredAttributes,
            withOriginalAttributes: originalAttributes
        ) as! InvalidationContext
        let heightDelta = preferredAttributes.size.height - originalAttributes.size.height
        
        invalidationContext.updatedAttributes = preferredAttributes
        invalidationContext.contentSizeAdjustment = CGSize(width: 0, height: heightDelta)
        
        return invalidationContext
    }

    // MARK: - Animation updates

    override open func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        let delete: (UICollectionViewUpdateItem) -> Void = { update in
            guard let ip = update.indexPathBeforeUpdate else { return }
            let idx = ip.item
//            var delta = self.currentItems[idx].height
//            if idx > 0 {
//                delta += self.spacing
//            }
//            for i in 0..<idx {
//                self.currentItems[i].offset -= delta
//            }
            self.cachedAttributes.remove(at: idx)
        }

        let insert: (UICollectionViewUpdateItem) -> Void = { update in
            guard let ip = update.indexPathAfterUpdate else { return }
            
            let idx = ip.item
            let item: UICollectionViewLayoutAttributes = {
                if idx == self.cachedAttributes.count {
                    let attrs = UICollectionViewLayoutAttributes(forCellWith: ip)
                    attrs.frame = CGRect(x: 0, y: 0, width: self.width, height: self.estimatedItemHeight)
                    return attrs
                } else {
                    let attrs = UICollectionViewLayoutAttributes(forCellWith: ip)
                    attrs.frame = CGRect(x: 0, y: self.cachedAttributes[idx].frame.maxY + self.spacing, width: self.width, height: self.cachedAttributes[idx].size.height)
                    return attrs
                }
            }()
            
            self.appearingItems.insert(item)
            let delta = item.size.height + self.spacing
//            for i in 0..<idx {
//                self.currentItems[i].offset += delta
//            }
            for i in (idx+1)..<self.cachedAttributes.count {
                let attrs = self.cachedAttributes[i]
                attrs.frame.origin.y += delta
                self.appearingItems.insert(attrs)
            }
            self.cachedAttributes.insert(item, at: idx)
        }

        for update in updateItems {
            switch update.updateAction {
            case .delete:
                delete(update)
            case .insert:
                insert(update)
            case .move:
                delete(update)
                insert(update)
            case .reload, .none: break
            @unknown default: break
            }
        }

        super.prepare(forCollectionViewUpdates: updateItems)
    }

    override open func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        appearingItems.forEach { attrs in
            let context = InvalidationContext(updatedAttributes: attrs)
            invalidateLayout(with: context)
        }
    }

    // MARK: - Main layout access

    override open func prepare() {
        guard let collectionView = collectionView else { return }
        
        var offset: CGFloat = 0
        
        for i in (0..<collectionView.numberOfItems(inSection: 0)) {
            let rowAttributes: UICollectionViewLayoutAttributes = {
                guard cachedAttributes.indices.contains(i) else {
                    let attrs = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
                    attrs.frame = CGRect(x: 0, y: offset, width: width, height: estimatedItemHeight)
                    cachedAttributes.append(attrs)
                    return attrs
                }
                
                cachedAttributes[i].frame = CGRect(x: 0, y: offset, width: width, height: cachedAttributes[i].size.height)
                return cachedAttributes[i]
            }()
            
            offset += rowAttributes.size.height
            offset += spacing
        }
        
        maxY = offset
    }

    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    // MARK: - Layout for collection view items

    override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cachedAttributes[indexPath.item]
    }
}
