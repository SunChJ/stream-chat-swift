// Created by bryankeller on 7/9/17.
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

import CoreGraphics
import Foundation

/// Represents the layout information for a section.
struct SectionModel {
    
    // MARK: Lifecycle
    
    init(
        itemModels: [ItemModel],
        metrics: MagazineLayoutSectionMetrics)
    {
        id = NSUUID().uuidString
        self.itemModels = itemModels
        self.metrics = metrics
        calculatedHeight = 0
        numberOfRows = 0
        
        updateIndexOfFirstInvalidatedRowIfNecessary(toProposedIndex: 0)
        calculateElementFramesIfNecessary()
    }
    
    // MARK: Internal
    
    let id: String
    
    var visibleBounds: CGRect?
    
    var numberOfItems: Int {
        return itemModels.count
    }
    
    func idForItemModel(atIndex index: Int) -> String {
        return itemModels[index].id
    }
    
    func indexForItemModel(withID id: String) -> Int? {
        return itemModels.firstIndex { $0.id == id }
    }
    
    func itemModel(atIndex index: Int) -> ItemModel {
        return itemModels[index]
    }
    
    func preferredHeightForItemModel(atIndex index: Int) -> CGFloat? {
        return itemModels[index].preferredHeight
    }
    
    mutating func calculateHeight() -> CGFloat {
        calculateElementFramesIfNecessary()
        
        return calculatedHeight
    }
    
    mutating func calculateFrameForItem(atIndex index: Int) -> CGRect {
        calculateElementFramesIfNecessary()
        
        var origin = itemModels[index].originInSection
        if let rowIndex = rowIndicesForItemIndices[index] {
            origin.y += rowOffsetTracker?.offsetForRow(at: rowIndex) ?? 0
        } else {
            assertionFailure("Expected a row and a row height for item at \(index).")
        }
        
        return CGRect(origin: origin, size: itemModels[index].size)
    }
    
    @discardableResult
    mutating func deleteItemModel(atIndex indexOfDeletion: Int) -> ItemModel {
        updateIndexOfFirstInvalidatedRow(forChangeToItemAtIndex: indexOfDeletion)
        
        return itemModels.remove(at: indexOfDeletion)
    }
    
    mutating func insert(_ itemModel: ItemModel, atIndex indexOfInsertion: Int) {
        updateIndexOfFirstInvalidatedRow(forChangeToItemAtIndex: indexOfInsertion)
        
        itemModels.insert(itemModel, at: indexOfInsertion)
    }
    
    mutating func updateMetrics(to metrics: MagazineLayoutSectionMetrics) {
        guard self.metrics != metrics else { return }
        
        self.metrics = metrics
        
        updateIndexOfFirstInvalidatedRowIfNecessary(toProposedIndex: 0)
    }
    
    mutating func updateItemHeight(toPreferredHeight preferredHeight: CGFloat, atIndex index: Int) {
        // Accessing this array using an unsafe, untyped (raw) pointer avoids expensive copy-on-writes
        // and Swift retain / release calls.
        let itemModelsPointer = UnsafeMutableRawPointer(mutating: &itemModels)
        let directlyMutableItemModels = itemModelsPointer.assumingMemoryBound(to: ItemModel.self)
        
        directlyMutableItemModels[index].preferredHeight = preferredHeight
        
        if
            let rowIndex = rowIndicesForItemIndices[index],
            let rowHeight = itemRowHeightsForRowIndices[rowIndex]
        {
            let newRowHeight = updateHeightsForItemsInRow(at: rowIndex)
            let heightDelta = newRowHeight - rowHeight
            
            calculatedHeight += heightDelta
            
            let firstAffectedRowIndex = rowIndex + 1
            if firstAffectedRowIndex < numberOfRows {
                rowOffsetTracker?.addOffset(heightDelta, forRowsStartingAt: firstAffectedRowIndex)
            }
        } else {
            assertionFailure("Expected a row and a row height for item at \(index).")
            return
        }
    }
    
    // MARK: Private
    
    private var numberOfRows: Int
    private var itemModels: [ItemModel]
    private var metrics: MagazineLayoutSectionMetrics
    private var calculatedHeight: CGFloat
    
    private var indexOfFirstInvalidatedRow: Int? {
        didSet {
            guard indexOfFirstInvalidatedRow != nil else { return }
            applyRowOffsetsIfNecessary()
        }
    }
    
    private var itemIndicesForRowIndices = [Int: [Int]]()
    private var rowIndicesForItemIndices = [Int: Int]()
    private var itemRowHeightsForRowIndices = [Int: CGFloat]()
    
    private var rowOffsetTracker: RowOffsetTracker?
    
    private func maxYForItemsRow(atIndex rowIndex: Int) -> CGFloat? {
        guard
            let itemIndices = itemIndicesForRowIndices[rowIndex],
            let itemY = itemIndices.first.flatMap({ itemModels[$0].originInSection.y }),
            let itemHeight = itemIndices.map({ itemModels[$0].size.height }).max() else
        {
            return nil
        }
        
        return itemY + itemHeight
    }
    
    private func indexOfFirstItemsRow() -> Int? {
        guard numberOfItems > 0 else { return nil }
        return 0
    }
    
    private func indexOfLastItemsRow() -> Int? {
        guard numberOfItems > 0 else { return nil }
        return rowIndicesForItemIndices[numberOfItems - 1]
    }
    
    private mutating func updateIndexOfFirstInvalidatedRow(forChangeToItemAtIndex changedIndex: Int) {
        guard
            let indexOfCurrentRow = rowIndicesForItemIndices[changedIndex],
            indexOfCurrentRow > 0 else
        {
            indexOfFirstInvalidatedRow = rowIndicesForItemIndices[0] ?? 0
            return
        }
        
        updateIndexOfFirstInvalidatedRowIfNecessary(toProposedIndex: indexOfCurrentRow - 1)
    }
    
    private mutating func updateIndexOfFirstInvalidatedRowIfNecessary(
        toProposedIndex proposedIndex: Int)
    {
        indexOfFirstInvalidatedRow = min(proposedIndex, indexOfFirstInvalidatedRow ?? proposedIndex)
    }
    
    private mutating func applyRowOffsetsIfNecessary() {
        guard let rowOffsetTracker = rowOffsetTracker else { return }
        
        for rowIndex in 0..<numberOfRows {
            let rowOffset = rowOffsetTracker.offsetForRow(at: rowIndex)
            for itemIndex in itemIndicesForRowIndices[rowIndex] ?? [] {
                itemModels[itemIndex].originInSection.y += rowOffset
            }
        }
        
        self.rowOffsetTracker = nil
    }
    
    private mutating func calculateElementFramesIfNecessary() {
        guard var rowIndex = indexOfFirstInvalidatedRow else { return }
        guard rowIndex >= 0 else {
            assertionFailure("Invalid `rowIndex` / `indexOfFirstInvalidatedRow` (\(rowIndex)).")
            return
        }
        
        // Clean up item / row / height mappings starting at our `indexOfFirstInvalidatedRow`; we'll
        // make new mappings for those row indices as we do layout calculations below. Since all
        // item / row index mappings before `indexOfFirstInvalidatedRow` are still valid, we'll leave
        // those alone.
        for rowIndexKey in itemIndicesForRowIndices.keys {
            guard rowIndexKey >= rowIndex else { continue }
            
            if let itemIndex = itemIndicesForRowIndices[rowIndexKey]?.first {
                rowIndicesForItemIndices[itemIndex] = nil
            }
            
            itemIndicesForRowIndices[rowIndexKey] = nil
            itemRowHeightsForRowIndices[rowIndex] = nil
        }
        
        var currentY: CGFloat
        
        // Item frame calculations
        
        let startingItemIndex: Int
        if
            let indexOfLastItemInPreviousRow = itemIndicesForRowIndices[rowIndex - 1]?.last,
            indexOfLastItemInPreviousRow + 1 < numberOfItems,
            let maxYForPreviousRow = maxYForItemsRow(atIndex: rowIndex - 1)
        {
            // There's a previous row of items, so we'll use the max Y of that row as the starting place
            // for the current row of items.
            startingItemIndex = indexOfLastItemInPreviousRow + 1
            currentY = maxYForPreviousRow + metrics.verticalSpacing
        } else if rowIndex == 0 {
            // Our starting row doesn't exist yet, so we'll lay out our first row of items.
            startingItemIndex = 0
            currentY = 0
        } else {
            // Our starting row is after the last row of items, so we'll skip item layout.
            startingItemIndex = numberOfItems
            if
                let lastRowIndex = indexOfLastItemsRow(),
                rowIndex > lastRowIndex,
                let maxYOfLastRowOfItems = maxYForItemsRow(atIndex: lastRowIndex)
            {
                currentY = maxYOfLastRowOfItems
            } else {
                currentY = 0
            }
        }
        
        // Accessing this array using an unsafe, untyped (raw) pointer avoids expensive copy-on-writes
        // and Swift retain / release calls.
        let itemModelsPointer = UnsafeMutableRawPointer(mutating: &itemModels)
        let directlyMutableItemModels = itemModelsPointer.assumingMemoryBound(to: ItemModel.self)
        
        var indexInCurrentRow = 0
        for itemIndex in startingItemIndex..<numberOfItems {
            // Create item / row index mappings
            itemIndicesForRowIndices[rowIndex] = itemIndicesForRowIndices[rowIndex] ?? []
            itemIndicesForRowIndices[rowIndex]?.append(itemIndex)
            rowIndicesForItemIndices[itemIndex] = rowIndex
            
            let availableWidthForItems = metrics.width
            
            let totalSpacing: CGFloat = 0
            let itemWidth = round(availableWidthForItems - totalSpacing)
            let itemX = CGFloat(indexInCurrentRow) * itemWidth
            let itemY = currentY
            
            directlyMutableItemModels[itemIndex].originInSection = CGPoint(x: itemX, y: itemY)
            directlyMutableItemModels[itemIndex].size.width = itemWidth
            
            if
                (indexInCurrentRow == 0) ||
                    (itemIndex == numberOfItems - 1)
            {
                // We've reached the end of the current row, or there are no more items to lay out, or we're
                // about to lay out an item with a different width mode. In all cases, we're done laying out
                // the current row of items.
                let heightOfTallestItemInCurrentRow = updateHeightsForItemsInRow(at: rowIndex)
                currentY += heightOfTallestItemInCurrentRow
                indexInCurrentRow = 0
                
                // If there are more items to layout, add vertical spacing and increment the row index
                if itemIndex < numberOfItems - 1 {
                    currentY += metrics.verticalSpacing
                    rowIndex += 1
                }
            } else {
                // We're still adding to the current row
                indexInCurrentRow += 1
            }
        }
        
        numberOfRows = rowIndex + 1
        
        // Final height calculation
        calculatedHeight = currentY
        
        // The background frame is calculated just-in-time, since its value doesn't affect the layout.
        
        // Create a row offset tracker now that we know how many rows we have
        rowOffsetTracker = RowOffsetTracker(numberOfRows: numberOfRows)
        
        // Mark the layout as clean / no longer invalid
        indexOfFirstInvalidatedRow = nil
    }
    
    private mutating func updateHeightsForItemsInRow(at rowIndex: Int) -> CGFloat {
        guard let indicesForItemsInRow = itemIndicesForRowIndices[rowIndex] else {
            assertionFailure("Expected item indices for row \(rowIndex).")
            return 0
        }
        
        // Accessing this array using an unsafe, untyped (raw) pointer avoids expensive copy-on-writes
        // and Swift retain / release calls.
        let itemModelsPointer = UnsafeMutableRawPointer(mutating: &itemModels)
        let directlyMutableItemModels = itemModelsPointer.assumingMemoryBound(to: ItemModel.self)
        
        var heightOfTallestItem = CGFloat(0)
        var stretchToTallestItemInRowItemIndices = Set<Int>()
        
        for itemIndex in indicesForItemsInRow {
            let preferredHeight = itemModels[itemIndex].preferredHeight
            let height = itemModels[itemIndex].size.height
            directlyMutableItemModels[itemIndex].size.height = preferredHeight ?? height
            
            // Handle stretch to tallest item in row height mode for current row
            
            heightOfTallestItem = max(heightOfTallestItem, itemModels[itemIndex].size.height)
        }
        
        for stretchToTallestItemInRowItemIndex in stretchToTallestItemInRowItemIndices{
            directlyMutableItemModels[stretchToTallestItemInRowItemIndex].size.height = heightOfTallestItem
        }
        
        itemRowHeightsForRowIndices[rowIndex] = heightOfTallestItem
        return heightOfTallestItem
    }
}
