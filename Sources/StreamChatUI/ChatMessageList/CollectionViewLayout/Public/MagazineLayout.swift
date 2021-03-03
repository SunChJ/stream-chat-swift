// Created by bryankeller on 6/26/17.
// Copyright © 2018 Airbnb, Inc.

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

import UIKit

/// A collection view layout that can display items in a grid and list arrangement.
///
/// Consumers should implement `UICollectionViewDelegateMagazineLayout`, which is used for all
/// `MagazineLayout` customizations.
///
/// Returning different `MagazineLayoutItemSizeMode`s from the delegate protocol implementation will
/// change how many items are displayed in a row and how each item sizes vertically.
public final class MagazineLayout: UICollectionViewLayout {
    
    // MARK: Lifecycle
    
    /// - Parameters:
    ///   - flipsHorizontallyInOppositeLayoutDirection: Indicates whether the horizontal coordinate
    ///     system is automatically flipped at appropriate times. In practice, this is used to support
    ///     right-to-left layout.
    public init(flipsHorizontallyInOppositeLayoutDirection: Bool = true) {
        _flipsHorizontallyInOppositeLayoutDirection = flipsHorizontallyInOppositeLayoutDirection
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        _flipsHorizontallyInOppositeLayoutDirection = true
        super.init(coder: aDecoder)
    }
    
    // MARK: Public
    
    override public class var invalidationContextClass: AnyClass {
        return MagazineLayoutInvalidationContext.self
    }
    
    override public var flipsHorizontallyInOppositeLayoutDirection: Bool {
        return _flipsHorizontallyInOppositeLayoutDirection
    }
    
    override public var collectionViewContentSize: CGSize {
        let numberOfSections = modelState.numberOfSections(.afterUpdates)
        
        let width: CGFloat
        if let collectionView = collectionView {
            let contentInset: UIEdgeInsets
            if #available(iOS 11.0, tvOS 11.0, *) {
                contentInset = collectionView.adjustedContentInset
            } else {
                contentInset = collectionView.contentInset
            }
            
            // This is a workaround for `layoutAttributesForElementsInRect:` not getting invoked enough
            // times if `collectionViewContentSize.width` is not smaller than the width of the collection
            // view, minus horizontal insets. This results in visual defects when performing batch
            // updates. To work around this, we subtract 0.0001 from our content size width calculation;
            // this small decrease in `collectionViewContentSize.width` is enough to work around the
            // incorrect, internal collection view `CGRect` checks, without introducing any visual
            // differences for elements in the collection view.
            // See https://openradar.appspot.com/radar?id=5025850143539200 for more details.
            width = collectionView.bounds.width - contentInset.left - contentInset.right - 0.0001
        } else {
            width = 0
        }
        
        let height: CGFloat
        if numberOfSections <= 0 {
            height = 0
        } else {
            height = modelState.sectionMaxY(forSectionAtIndex: numberOfSections - 1, .afterUpdates)
        }
        
        return CGSize(width: width, height: height)
    }
    
    override public func prepare() {
        super.prepare()
        
        guard !prepareActions.isEmpty else { return }
        
        // Save the previous collection view width if necessary
        if prepareActions.contains(.cachePreviousWidth) {
            cachedCollectionViewWidth = currentCollectionView.bounds.width
        }
        
        if
            prepareActions.contains(.updateLayoutMetrics) ||
                prepareActions.contains(.recreateSectionModels)
        {
            hasPinnedHeaderOrFooter = false
        }
        
        // Update layout metrics if necessary
        if
            prepareActions.contains(.updateLayoutMetrics) &&
                !prepareActions.contains(.recreateSectionModels) &&
                !prepareActions.contains(.lazilyCreateLayoutAttributes)
        {
            for sectionIndex in 0..<modelState.numberOfSections(.afterUpdates) {
                let sectionMetrics = metricsForSection(atIndex: sectionIndex)
                modelState.updateMetrics(to: sectionMetrics, forSectionAtIndex: sectionIndex)
            }
        }
        
        var newItemLayoutAttributes = [ElementLocation: UICollectionViewLayoutAttributes]()
        
        var sections = [SectionModel]()
        for sectionIndex in 0..<currentCollectionView.numberOfSections {
            // Recreate section models from scratch if necessary
            if prepareActions.contains(.recreateSectionModels) {
                let sectionModel = sectionModelForSection(atIndex: sectionIndex)
                sections.append(sectionModel)
            }
            
            let numberOfItems = currentCollectionView.numberOfItems(inSection: sectionIndex)
            
            // Create item layout attributes if necessary
            for itemIndex in 0..<numberOfItems {
                let itemLocation = ElementLocation(elementIndex: itemIndex, sectionIndex: sectionIndex)
                
                if let itemLayoutAttributes = itemLayoutAttributes[itemLocation] {
                    newItemLayoutAttributes[itemLocation] = itemLayoutAttributes
                } else {
                    newItemLayoutAttributes[itemLocation] = UICollectionViewLayoutAttributes(
                        forCellWith: itemLocation.indexPath)
                }
                
                newItemLayoutAttributes[itemLocation]?.zIndex = numberOfItems - itemIndex
            }
        }
        
        if prepareActions.contains(.recreateSectionModels) {
            modelState.setSections(sections)
        }
        
        if prepareActions.contains(.lazilyCreateLayoutAttributes) {
            itemLayoutAttributes = newItemLayoutAttributes
        }
        
        if
            prepareActions.contains(.recreateSectionModels) ||
                prepareActions.contains(.updateLayoutMetrics)
        {
            lastSizedElementMinY = nil
            lastSizedElementPreferredHeight = nil
        }
        
        prepareActions = []
    }
    
    override public func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        var updates = [CollectionViewUpdate<SectionModel, ItemModel>]()
        
        for updateItem in updateItems {
            let updateAction = updateItem.updateAction
            let indexPathBeforeUpdate = updateItem.indexPathBeforeUpdate
            let indexPathAfterUpdate = updateItem.indexPathAfterUpdate
            
            if updateAction == .reload {
                guard let indexPath = indexPathBeforeUpdate else {
                    assertionFailure("`indexPathBeforeUpdate` cannot be `nil` for a `.reload` update action")
                    return
                }
                
                if indexPath.item == NSNotFound {
                    let sectionModel = sectionModelForSection(atIndex: indexPath.section)
                    updates.append(.sectionReload(sectionIndex: indexPath.section, newSection: sectionModel))
                } else {
                    let itemModel = itemModelForItem(at: indexPath)
                    updates.append(.itemReload(itemIndexPath: indexPath, newItem: itemModel))
                }
            }
            
            if updateAction == .delete {
                guard let indexPath = indexPathBeforeUpdate else {
                    assertionFailure("`indexPathBeforeUpdate` cannot be `nil` for a `.delete` update action")
                    return
                }
                
                if indexPath.item == NSNotFound {
                    updates.append(.sectionDelete(sectionIndex: indexPath.section))
                } else {
                    updates.append(.itemDelete(itemIndexPath: indexPath))
                }
            }
            
            if updateAction == .insert {
                guard let indexPath = indexPathAfterUpdate else {
                    assertionFailure("`indexPathAfterUpdate` cannot be `nil` for an `.insert` update action")
                    return
                }
                
                if indexPath.item == NSNotFound {
                    let sectionModel = sectionModelForSection(atIndex: indexPath.section)
                    updates.append(.sectionInsert(sectionIndex: indexPath.section, newSection: sectionModel))
                } else {
                    let itemModel = itemModelForItem(at: indexPath)
                    updates.append(.itemInsert(itemIndexPath: indexPath, newItem: itemModel))
                }
            }
            
            if updateAction == .move {
                guard
                    let initialIndexPath = indexPathBeforeUpdate,
                    let finalIndexPath = indexPathAfterUpdate else
                {
                    assertionFailure("`indexPathBeforeUpdate` and `indexPathAfterUpdate` cannot be `nil` for a `.move` update action")
                    return
                }
                
                if initialIndexPath.item == NSNotFound && finalIndexPath.item == NSNotFound {
                    updates.append(.sectionMove(
                                    initialSectionIndex: initialIndexPath.section,
                                    finalSectionIndex: finalIndexPath.section))
                } else {
                    updates.append(.itemMove(
                                    initialItemIndexPath: initialIndexPath,
                                    finalItemIndexPath: finalIndexPath))
                }
            }
        }
        
        modelState.applyUpdates(updates)
        hasDataSourceCountInvalidationBeforeReceivingUpdateItems = false
        
        super.prepare(forCollectionViewUpdates: updateItems)
    }
    
    override public func finalizeCollectionViewUpdates() {
        modelState.clearInProgressBatchUpdateState()
        
        itemLayoutAttributesForPendingAnimations.removeAll()
        supplementaryViewLayoutAttributesForPendingAnimations.removeAll()
        
        super.finalizeCollectionViewUpdates()
    }
    
    override public func layoutAttributesForElements(
        in rect: CGRect)
    -> [UICollectionViewLayoutAttributes]?
    {
        // This early return prevents an issue that causes overlapping / misplaced elements after an
        // off-screen batch update occurs. The root cause of this issue is that `UICollectionView`
        // expects `layoutAttributesForElementsInRect:` to return post-batch-update layout attributes
        // immediately after an update is sent to the collection view via the insert/delete/reload/move
        // functions. Unfortunately, this is impossible - when batch updates occur, `invalidateLayout:`
        // is invoked immediately with a context that has `invalidateDataSourceCounts` set to `true`.
        // At this time, `MagazineLayout` has no way of knowing the details of this data source count
        // change (where the insert/delete/move took place). `MagazineLayout` only gets this additional
        // information once `prepareForCollectionViewUpdates:` is invoked. At that time, we're able to
        // update our layout's source of truth, the `ModelState`, which allows us to resolve the
        // post-batch-update layout and return post-batch-update layout attributes from this function.
        // Between the time that `invalidateLayout:` is invoked with `invalidateDataSourceCounts` set to
        // `true`, and when `prepareForCollectionViewUpdates:` is invoked with details of the updates,
        // `layoutAttributesForElementsInRect:` is invoked with the expectation that we already have a
        // fully resolved layout. If we return incorrect layout attributes at that time, then we'll have
        // overlapping elements / visual defects. To prevent this, we can return `nil` in this
        // situation, which works around the bug.
        // `UICollectionViewCompositionalLayout`, in classic UIKit fashion, avoids this bug / feature by
        // implementing the private function
        // `_prepareForCollectionViewUpdates:withDataSourceTranslator:`, which provides the layout with
        // details about the updates to the collection view before `layoutAttributesForElementsInRect:`
        // is invoked, enabling them to resolve their layout in time.
        guard !hasDataSourceCountInvalidationBeforeReceivingUpdateItems else { return nil }
        
        var layoutAttributesInRect = [UICollectionViewLayoutAttributes]()
        
        let itemLocationFramePairs = modelState.itemLocationFramePairs(forItemsIn: rect)
        for itemLocationFramePair in itemLocationFramePairs {
            let itemLocation = itemLocationFramePair.elementLocation
            let itemFrame = itemLocationFramePair.frame
            
            guard let layoutAttributes = itemLayoutAttributes[itemLocation] else {
                continue
            }
            
            layoutAttributes.frame = itemFrame
            layoutAttributesInRect.append(layoutAttributes)
        }
        
        return layoutAttributesInRect
    }
    
    override public func layoutAttributesForItem(
        at indexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
    {
        // See comment in `layoutAttributesForElementsInRect:` for more details.
        guard !hasDataSourceCountInvalidationBeforeReceivingUpdateItems else { return nil }
        
        let itemLocation = ElementLocation(indexPath: indexPath)
        let layoutAttributes = itemLayoutAttributes[itemLocation]
        
        guard
            itemLocation.sectionIndex < modelState.numberOfSections(.afterUpdates),
            itemLocation.elementIndex < modelState.numberOfItems(inSectionAtIndex: itemLocation.sectionIndex, .afterUpdates)
        else
        {
            // On iOS 9, `layoutAttributesForItem(at:)` can be invoked for an index path of a new item
            // before the layout is notified of this new item (through either `prepare` or
            // `prepare(forCollectionViewUpdates:)`). This seems to be fixed in iOS 10 and higher.
            assertionFailure("`{\(itemLocation.sectionIndex), \(itemLocation.elementIndex)}` is out of bounds of the section models / item models array.")
            
            // Returning `nil` rather than default/frameless layout attributes causes internal exceptions
            // within `UICollecionView`, which is why we don't return `nil` here.
            return layoutAttributes
        }
        
        layoutAttributes?.frame = modelState.frameForItem(at: itemLocation, .afterUpdates)
        
        return layoutAttributes
    }
    
    override public func initialLayoutAttributesForAppearingItem(
        at itemIndexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
    {
        if
            modelState.itemIndexPathsToInsert.contains(itemIndexPath) ||
                modelState.sectionIndicesToInsert.contains(itemIndexPath.section)
        {
            let attributes = layoutAttributesForItem(at: itemIndexPath)?.copy() as? UICollectionViewLayoutAttributes
            attributes.map {
                delegateMagazineLayout?.collectionView(
                    currentCollectionView,
                    layout: self,
                    initialLayoutAttributesForInsertedItemAt: itemIndexPath,
                    byModifying: $0)
            }
            itemLayoutAttributesForPendingAnimations[itemIndexPath] = attributes
            return attributes
        } else if
            let movedItemID = modelState.idForItemModel(at: itemIndexPath, .afterUpdates),
            let initialIndexPath = modelState.indexPathForItemModel(
                withID: movedItemID,
                .beforeUpdates)
        {
            return previousLayoutAttributesForItem(at: initialIndexPath)
        } else {
            return super.layoutAttributesForItem(at: itemIndexPath)
        }
    }
    
    override public func finalLayoutAttributesForDisappearingItem(
        at itemIndexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
    {
        if
            modelState.itemIndexPathsToDelete.contains(itemIndexPath) ||
                modelState.sectionIndicesToDelete.contains(itemIndexPath.section)
        {
            let attributes = previousLayoutAttributesForItem(at: itemIndexPath)
            attributes.map {
                delegateMagazineLayout?.collectionView(
                    currentCollectionView,
                    layout: self,
                    finalLayoutAttributesForRemovedItemAt: itemIndexPath,
                    byModifying: $0)
            }
            return attributes
        } else if
            let movedItemID = modelState.idForItemModel(at: itemIndexPath, .beforeUpdates),
            let finalIndexPath = modelState.indexPathForItemModel(
                withID: movedItemID,
                .afterUpdates)
        {
            let attributes = layoutAttributesForItem(at: finalIndexPath)?.copy() as? UICollectionViewLayoutAttributes
            itemLayoutAttributesForPendingAnimations[finalIndexPath] = attributes
            return attributes
        } else {
            return super.layoutAttributesForItem(at: itemIndexPath)
        }
    }
    
    override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return  collectionView?.bounds.size.width != .some(newBounds.size.width) ||
            hasPinnedHeaderOrFooter
    }
    
    override public func invalidationContext(
        forBoundsChange newBounds: CGRect)
    -> UICollectionViewLayoutInvalidationContext
    {
        let invalidationContext = super.invalidationContext(
            forBoundsChange: newBounds) as! MagazineLayoutInvalidationContext
        
        invalidationContext.contentSizeAdjustment = CGSize(
            width: newBounds.width - currentCollectionView.bounds.width,
            height: newBounds.height - currentCollectionView.bounds.height)
        invalidationContext.invalidateLayoutMetrics = false
        
        return invalidationContext
    }
    
    override public func shouldInvalidateLayout(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes)
    -> Bool
    {
        guard !preferredAttributes.indexPath.isEmpty else {
            return super.shouldInvalidateLayout(
                forPreferredLayoutAttributes: preferredAttributes,
                withOriginalAttributes: originalAttributes)
        }
        
        let hasNewPreferredHeight = preferredAttributes.size.height.rounded() != originalAttributes.size.height.rounded()
        return hasNewPreferredHeight
    }
    
    override public func invalidationContext(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes)
    -> UICollectionViewLayoutInvalidationContext
    {
        switch preferredAttributes.representedElementCategory {
        case .cell:
            modelState.updateItemHeight(
                toPreferredHeight: preferredAttributes.size.height,
                forItemAt: preferredAttributes.indexPath)
            
            let layoutAttributesForPendingAnimation = itemLayoutAttributesForPendingAnimations[preferredAttributes.indexPath]
            layoutAttributesForPendingAnimation?.frame.size.height = modelState.frameForItem(
                at: ElementLocation(indexPath: preferredAttributes.indexPath),
                .afterUpdates).height
            
        default:
            break
        }
        
        let currentElementY = originalAttributes.frame.minY
        
        let context = super.invalidationContext(
            forPreferredLayoutAttributes: preferredAttributes,
            withOriginalAttributes: originalAttributes) as! MagazineLayoutInvalidationContext
        
        // If layout information is discarded above our current scroll position (on rotation, for
        // example), we need to compensate for preferred size changes to items as we're scrolling up,
        // otherwise, the collection view will appear to jump each time an element is sized.
        // Since size adjustments can occur for multiple items in the same soon-to-be-visible row, we
        // need to account for this by considering the preferred height for previously sized elements in
        // the same row so that we only adjust the content offset by the exact amount needed to create
        // smooth scrolling.
        let isScrolling = currentCollectionView.isDragging || currentCollectionView.isDecelerating
        let isSizingElementAboveTopEdge = originalAttributes.frame.minY < currentCollectionView.contentOffset.y
        
        if isScrolling && isSizingElementAboveTopEdge {
            let isSameRowAsLastSizedElement = lastSizedElementMinY == currentElementY
            if isSameRowAsLastSizedElement {
                let lastSizedElementPreferredHeight = self.lastSizedElementPreferredHeight ?? 0
                if preferredAttributes.size.height > lastSizedElementPreferredHeight {
                    context.contentOffsetAdjustment.y = preferredAttributes.size.height - lastSizedElementPreferredHeight
                }
            } else {
                context.contentOffsetAdjustment.y = preferredAttributes.size.height - originalAttributes.size.height
            }
        }
        
        lastSizedElementMinY = currentElementY
        lastSizedElementPreferredHeight = preferredAttributes.size.height
        
        context.invalidateLayoutMetrics = false
        
        return context
    }
    
    override public func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        guard let context = context as? MagazineLayoutInvalidationContext else {
            assertionFailure("`context` must be an instance of `MagazineLayoutInvalidationContext`")
            return
        }
        
        if context.invalidateEverything {
            prepareActions.formUnion([.recreateSectionModels, .lazilyCreateLayoutAttributes])
        }
        
        if context.invalidateDataSourceCounts {
            prepareActions.formUnion(.lazilyCreateLayoutAttributes)
        }
        
        hasDataSourceCountInvalidationBeforeReceivingUpdateItems = context.invalidateDataSourceCounts &&
            !context.invalidateEverything
        
        // Checking `cachedCollectionViewWidth != collectionView?.bounds.size.width` is necessary
        // because the collection view's width can change without a `contentSizeAdjustment` occuring.
        if
            context.contentSizeAdjustment.width != 0 ||
                cachedCollectionViewWidth != collectionView?.bounds.size.width
        {
            prepareActions.formUnion([.updateLayoutMetrics, .cachePreviousWidth])
        }
        
        if context.invalidateLayoutMetrics {
            prepareActions.formUnion([.updateLayoutMetrics])
        }
        
        super.invalidateLayout(with: context)
    }
    
    // MARK: Private
    
    private var currentCollectionView: UICollectionView {
        guard let collectionView = collectionView else {
            preconditionFailure("`collectionView` should not be `nil`")
        }
        
        return collectionView
    }
    
    private lazy var modelState: ModelState = {
        return ModelState(currentVisibleBoundsProvider: { [weak self] in
            return self?.currentVisibleBounds ?? .zero
        })
    }()
    
    private let _flipsHorizontallyInOppositeLayoutDirection: Bool
    
    private var cachedCollectionViewWidth: CGFloat?
    
    // These properties are used to prevent scroll jumpiness due to self-sizing after rotation; see
    // comment in `invalidationContext(forPreferredLayoutAttributes:withOriginalAttributes:)` for more
    // details.
    private var lastSizedElementMinY: CGFloat?
    private var lastSizedElementPreferredHeight: CGFloat?
    
    private var hasPinnedHeaderOrFooter: Bool = false
    
    // Cached layout attributes; lazily populated using information from the model state.
    private var itemLayoutAttributes = [ElementLocation: UICollectionViewLayoutAttributes]()
    private var headerLayoutAttributes = [ElementLocation: UICollectionViewLayoutAttributes]()
    private var footerLayoutAttributes = [ElementLocation: UICollectionViewLayoutAttributes]()
    private var backgroundLayoutAttributes = [ElementLocation: UICollectionViewLayoutAttributes]()
    
    // These properties are used to keep the layout attributes copies used for insert/delete
    // animations up-to-date as items are self-sized. If we don't keep these copies up-to-date, then
    // animations will start from the estimated height.
    private var itemLayoutAttributesForPendingAnimations = [IndexPath: UICollectionViewLayoutAttributes]()
    private var supplementaryViewLayoutAttributesForPendingAnimations = [IndexPath: UICollectionViewLayoutAttributes]()
    
    private struct PrepareActions: OptionSet {
        let rawValue: UInt
        
        static let recreateSectionModels = PrepareActions(rawValue: 1 << 0)
        static let lazilyCreateLayoutAttributes = PrepareActions(rawValue: 1 << 1)
        static let updateLayoutMetrics = PrepareActions(rawValue: 1 << 2)
        static let cachePreviousWidth = PrepareActions(rawValue: 1 << 3)
    }
    private var prepareActions: PrepareActions = []
    
    // Used to prevent a collection view bug / animation issue that occurs when off-screen batch
    // updates cause changes to the elements in the visible region. See comment in
    // `layoutAttributesForElementsInRect:` for more details.
    private var hasDataSourceCountInvalidationBeforeReceivingUpdateItems = false
    
    // Used to provide the model state with the current visible bounds for the sole purpose of
    // supporting pinned headers and footers.
    private var currentVisibleBounds: CGRect {
        let contentInset: UIEdgeInsets
        if #available(iOS 11.0, tvOS 11.0, *) {
            contentInset = currentCollectionView.adjustedContentInset
        } else {
            contentInset = currentCollectionView.contentInset
        }
        
        let refreshControlHeight: CGFloat
        #if os(iOS)
        if
            let refreshControl = currentCollectionView.refreshControl,
            refreshControl.isRefreshing
        {
            refreshControlHeight = refreshControl.bounds.height
        } else {
            refreshControlHeight = 0
        }
        #else
        refreshControlHeight = 0
        #endif
        
        return CGRect(
            x: currentCollectionView.bounds.minX + contentInset.left,
            y: currentCollectionView.bounds.minY + contentInset.top - refreshControlHeight,
            width: currentCollectionView.bounds.width - contentInset.left - contentInset.right,
            height: currentCollectionView.bounds.height - contentInset.top - contentInset.bottom + refreshControlHeight)
    }
    
    private var delegateMagazineLayout: UICollectionViewDelegateMagazineLayout? {
        return currentCollectionView.delegate as? UICollectionViewDelegateMagazineLayout
    }
    
    private func metricsForSection(atIndex sectionIndex: Int) -> MagazineLayoutSectionMetrics {
        guard let delegateMagazineLayout = delegateMagazineLayout else {
            return MagazineLayoutSectionMetrics.defaultSectionMetrics(
                forCollectionViewWidth: currentCollectionView.bounds.width)
        }
        
        return MagazineLayoutSectionMetrics(
            forSectionAtIndex: sectionIndex,
            in: currentCollectionView,
            layout: self,
            delegate: delegateMagazineLayout)
    }
    
    private func sectionModelForSection(atIndex sectionIndex: Int) -> SectionModel {
        let itemModels = (0..<currentCollectionView.numberOfItems(inSection: sectionIndex)).map {
            itemModelForItem(at: IndexPath(item: $0, section: sectionIndex))
        }
        
        return SectionModel(
            itemModels: itemModels,
            metrics: metricsForSection(atIndex: sectionIndex)
        )
    }
    
    private func itemModelForItem(at indexPath: IndexPath) -> ItemModel {
        return ItemModel(height: Default.ItemHeight)
    }
    
    private func previousLayoutAttributesForItem(
        at indexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
    {
        let layoutAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        
        guard modelState.isPerformingBatchUpdates else {
            // TODO(bryankeller): Look into whether this happens on iOS 10. It definitely does on iOS 9.
            
            // Returning `nil` rather than default/frameless layout attributes causes internal exceptions
            // within `UICollecionView`, which is why we don't return `nil` here.
            return layoutAttributes
        }
        
        guard
            indexPath.section < modelState.numberOfSections(.beforeUpdates),
            indexPath.item < modelState.numberOfItems(inSectionAtIndex: indexPath.section, .beforeUpdates) else
        {
            // On iOS 9, `layoutAttributesForItem(at:)` can be invoked for an index path of a new item
            // before the layout is notified of this new item (through either `prepare` or
            // `prepare(forCollectionViewUpdates:)`). This seems to be fixed in iOS 10 and higher.
            assertionFailure("`{\(indexPath.section), \(indexPath.item)}` is out of bounds of the section models / item models array.")
            
            // Returning `nil` rather than default/frameless layout attributes causes internal exceptions
            // within `UICollecionView`, which is why we don't return `nil` here.
            return layoutAttributes
        }
        
        layoutAttributes.frame = modelState.frameForItem(
            at: ElementLocation(indexPath: indexPath),
            .beforeUpdates)
        
        return layoutAttributes
    }
}
