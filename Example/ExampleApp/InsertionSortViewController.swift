/*
 Apple, iPhone, iMac, iPad Pro, Apple Pencil, Apple Watch, App Store, TestFlight, Siri, and SiriKit are trademarks of Apple, Inc.
 
 The following license applies to the source code, and other elements of this package:
 
 Copyright © 2023 Apple Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 Abstract:
 Visual illustration of an insertion sort using diffable data sources to update the UI
 */

import UIKit
import DiffableDataSource
class InsertionSortViewController: UIViewController {
  
  static let nodeSize = CGSize(width: 16, height: 34)
  static let reuseIdentifier = "cell-id"
  var insertionCollectionView: UICollectionView! = nil
  var dataSource: DiffableDataSource
  <InsertionSortArray, InsertionSortArray.SortNode>! = nil
  var isSorting = false
  var isSorted = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "Insertion Sort Visualizer"
    configureHierarchy()
    configureDataSource()
    configureNavItem()
  }
}

extension InsertionSortViewController {
  
  func configureHierarchy() {
    insertionCollectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout())
    insertionCollectionView.backgroundColor = .black
    insertionCollectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(insertionCollectionView)
  }
  func configureNavItem() {
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: isSorting ? "Stop" : "Sort",
                                                        style: .plain, target: self,
                                                        action: #selector(toggleSort))
  }
  @objc
  func toggleSort() {
    isSorting.toggle()
    if isSorting {
      performSortStep()
    }
    configureNavItem()
  }
  /// - Tag: InsertionSortStep
  func performSortStep() {
    if !isSorting {
      return
    }
    
    var sectionCountNeedingSort = 0
    
    // Get the current state of the UI from the data source.
    var updatedSnapshot = dataSource.snapshot()
    
    // For each section, if needed, step through and perform the next sorting step.
    updatedSnapshot.sectionIdentifiers.forEach {
      let section = $0
      if !section.isSorted {
        
        // Step the sort algorithm.
        section.sortNext()
        let items = section.values
        
        // Replace the items for this section with the newly sorted items.
        updatedSnapshot.deleteItems(items, fromSection: section)
        updatedSnapshot.appendItems(items, toSection: section)
        
        sectionCountNeedingSort += 1
      }
    }
    
    var shouldReset = false
    var delay = 125
    if sectionCountNeedingSort > 0 {
      dataSource.apply(updatedSnapshot)
    } else {
      delay = 1000
      shouldReset = true
    }
    let bounds = insertionCollectionView.bounds
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
      if shouldReset {
        let snapshot = self.randomizedSnapshot(for: bounds)
        self.dataSource.apply(snapshot)
      }
      self.performSortStep()
    }
  }
  func layout() -> UICollectionViewLayout {
    let layout = UICollectionViewCompositionalLayout {
      (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
      let contentSize = layoutEnvironment.container.effectiveContentSize
      let columns = Int(contentSize.width / InsertionSortViewController.nodeSize.width)
      let rowHeight = InsertionSortViewController.nodeSize.height
      let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                        heightDimension: .fractionalHeight(1.0))
      let item = NSCollectionLayoutItem(layoutSize: size)
      let groupSize = NSCollectionLayoutSize(
        widthDimension: .estimated(InsertionSortViewController.nodeSize.width),
        heightDimension: .absolute(rowHeight)
      )
      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: groupSize,
        repeatingSubitem: item,
        count: columns
      )
      let section = NSCollectionLayoutSection(group: group)
      return section
    }
    return layout
  }
  func configureDataSource() {
    
    let cellRegistration = UICollectionView.CellRegistration
    <UICollectionViewCell, InsertionSortArray.SortNode> { (cell, indexPath, sortNode) in
      // Populate the cell with our item description.
      cell.backgroundColor = sortNode.color
    }
    
    dataSource = .init(collectionView: insertionCollectionView) {
      (collectionView: UICollectionView, indexPath: IndexPath, node: InsertionSortArray.SortNode) -> UICollectionViewCell in
      return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: node)
      
    }
    
    let bounds = insertionCollectionView.bounds
    let snapshot = randomizedSnapshot(for: bounds)
    dataSource.apply(snapshot)
  }
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    if dataSource != nil {
      let bounds = insertionCollectionView.bounds
      let snapshot = randomizedSnapshot(for: bounds)
      dataSource.apply(snapshot)
    }
  }
  func randomizedSnapshot(
    for bounds: CGRect
  ) -> DiffableDataSourceSnapshot<
    InsertionSortArray,
    InsertionSortArray.SortNode
  > {
    var snapshot = DiffableDataSourceSnapshot<InsertionSortArray, InsertionSortArray.SortNode>()
    let rowCount = rows(for: bounds)
    let columnCount = columns(for: bounds)
    for _ in 0..<rowCount {
      let section = InsertionSortArray(count: columnCount)
      snapshot.appendSections([section])
      snapshot.appendItems(section.values, toSection: section)
    }
    return snapshot
  }
  func rows(for bounds: CGRect) -> Int {
    return Int(bounds.height / InsertionSortViewController.nodeSize.height)
  }
  func columns(for bounds: CGRect) -> Int {
    return Int(bounds.width / InsertionSortViewController.nodeSize.width)
  }
}


