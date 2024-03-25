import UIKit

@MainActor 
public struct
DiffableDataSource<Section: Identifiable, Item: Hashable> {
  private let dataSource: _DataSource
  public init(
    collectionView: UICollectionView,
    initial: DiffableSnapshot<Section, Item>,
    cellProvider: @escaping CellProvider
  ) {
    dataSource = .init(
      collectionView: collectionView,
      initial: initial,
      cellProvider: cellProvider
    )
  }
  
  public func apply(_ snapshot: DiffableSnapshot<Section, Item>) {
    dataSource.apply(snapshot)
  }
  
  public func snapshot() -> DiffableSnapshot<Section, Item> {
    dataSource.currentSnapshot
  }
  
  public typealias Registration<CellType: UICollectionViewCell> = UICollectionView
    .CellRegistration<CellType, Item>
  
  public typealias CellProvider = (
    UICollectionView,
    IndexPath,
    Item
  ) -> UICollectionViewCell
  
  internal typealias Changes = (
    itemInsertions: Set<IndexPath>,
    itemRemovals: Set<IndexPath>,
    sectionInsertions: IndexSet,
    sectionRemovals: IndexSet
  )
}

extension DiffableDataSource: Sendable
where
Item: Sendable,
Section: Sendable {}

public struct DiffableSnapshot<Section: Identifiable, Item: Hashable> {
  public private(set) var sectionIdentifiers = [Section]()
  internal var sections = [Section.ID]()
  internal var items = [Section.ID: [Item]]()
  
  public init() {
    self.sectionIdentifiers = .init()
    self.sections = .init()
    self.items = .init()
  }
  
  public mutating func appendSections(_ sections: [Section]) {
    self.sections.append(contentsOf: sections.map(\.id))
    self.sectionIdentifiers.append(contentsOf: sections)
  }
  
  public mutating func appendItems(_ items: [Item], toSection section: Section) {
    self.items[section.id, default: []].append(contentsOf: items)
  }
  
  public mutating func deleteItems(_ items: [Item], inSection section: Section) {
    self.items[section.id]!.removeAll(where: items.contains)
  }
  
  internal func difference(from oldValue: DiffableSnapshot) -> Changes {
    var changes = Changes(.init(), .init(), .init(), .init())
    for (index, section) in oldValue.sections.enumerated() {
      guard let newItems = items[section]
      else { continue }
      for change in newItems
        .difference(from: oldValue.items[section, default: []]) {
        switch change {
        case let .remove(offset, _, _):
          changes.itemRemovals.insert(IndexPath(row: offset, section: index))
        case let .insert(offset, _, _):
          changes.itemInsertions.insert(IndexPath(row: offset, section: index))
        }
      }
    }
    for change in self
      .sections
      .difference(from: oldValue.sections) {
      switch change {
      case let .remove(offset, _, _):
        changes.sectionRemovals.insert(offset)
      case let .insert(offset, element, _):
        // all items in a new section are insertions
        items[element, default: []].indices.forEach { index in
          changes.itemInsertions.insert(.init(row: index, section: offset))
        }
        changes.sectionInsertions.insert(offset)
      }
    }
    return changes
  }
  
  internal typealias Changes = (
    itemInsertions: Set<IndexPath>,
    itemRemovals: Set<IndexPath>,
    sectionInsertions: IndexSet,
    sectionRemovals: IndexSet
  )
}

extension DiffableSnapshot: Sendable
where
Section: Sendable,
Section.ID: Sendable,
Item: Sendable {}

internal extension DiffableDataSource {
  private final class _DataSource:
    NSObject, UICollectionViewDataSource, Sendable
  {
    var currentSnapshot = DiffableSnapshot<Section, Item>()
    let cellProvider: CellProvider
    let collectionView: UICollectionView
    
    init(
      collectionView: UICollectionView,
      initial: DiffableSnapshot<Section, Item>,
      cellProvider: @escaping CellProvider
    ) {
      self.cellProvider = cellProvider
      self.collectionView = collectionView
      self.currentSnapshot = initial
      super.init()
      collectionView.dataSource = self
    }
    
    func collectionView(
      _ collectionView: UICollectionView,
      numberOfItemsInSection section: Int
    ) -> Int {
      currentSnapshot.items[currentSnapshot.sections[section]]!.count
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
      currentSnapshot.sections.count
    }
    
    func collectionView(
      _ collectionView: UICollectionView,
      cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
      let item = currentSnapshot.items[
        currentSnapshot
          .sections[indexPath.section]
      ]![indexPath.row]
      return cellProvider(collectionView, indexPath, item)
    }
    
    func apply(_ snapshot: DiffableSnapshot<Section, Item>) {
      let changes = snapshot.difference(from: currentSnapshot)
      collectionView.performBatchUpdates { [unowned self] in
        currentSnapshot = snapshot
        collectionView.deleteSections(changes.sectionRemovals)
        collectionView.insertSections(changes.sectionInsertions)
        collectionView.deleteItems(at: Array(changes.itemRemovals))
        collectionView.insertItems(at: Array(changes.itemInsertions))
      }
    }
  }
}
