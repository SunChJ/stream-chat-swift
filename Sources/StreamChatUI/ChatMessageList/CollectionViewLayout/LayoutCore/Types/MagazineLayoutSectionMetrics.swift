// Created by bryankeller on 10/26/18.
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

/// Encapsulates all layout-affecting metrics relating to a section
struct MagazineLayoutSectionMetrics: Equatable {
    
    // MARK: Lifecycle
    
    init(
        forSectionAtIndex sectionIndex: Int,
        in collectionView: UICollectionView,
        layout: UICollectionViewLayout,
        verticalSpacing: CGFloat)
    {
        collectionViewWidth = collectionView.bounds.width
        
        if #available(iOS 11.0, tvOS 11.0, *) {
            collectionViewContentInset = collectionView.adjustedContentInset
        } else {
            collectionViewContentInset = collectionView.contentInset
        }
        
        self.verticalSpacing = verticalSpacing
    }
    
    private init(
        collectionViewWidth: CGFloat,
        collectionViewContentInset: UIEdgeInsets,
        verticalSpacing: CGFloat
    ) {
        self.collectionViewWidth = collectionViewWidth
        self.collectionViewContentInset = collectionViewContentInset
        self.verticalSpacing = verticalSpacing
    }
    
    // MARK: Internal
    
    var width: CGFloat {
        return collectionViewWidth -
            collectionViewContentInset.left -
            collectionViewContentInset.right
    }
    
    var verticalSpacing: CGFloat
    
    static func defaultSectionMetrics(
        forCollectionViewWidth width: CGFloat)
    -> MagazineLayoutSectionMetrics
    {
        return MagazineLayoutSectionMetrics(
            collectionViewWidth: width,
            collectionViewContentInset: .zero,
            verticalSpacing: MagazineLayout.Default.VerticalSpacing
        )
    }
    
    // MARK: Private
    
    private let collectionViewWidth: CGFloat
    private let collectionViewContentInset: UIEdgeInsets
    
}
