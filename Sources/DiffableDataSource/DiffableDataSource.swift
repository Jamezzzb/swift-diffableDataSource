import UIKit

@MainActor
public struct
DiffableDataSource<Section: Identifiable, Item: Hashable> {
  private let dataSource: _DataSource
  public init(
    collectionView: UICollectionView,
    initial: DiffableDataSourceSnapshot<Section, Item> = .init(),
    cellProvider: @escaping CellProvider
  ) {
    dataSource = .init(
      collectionView: collectionView,
      initial: initial,
      cellProvider: cellProvider
    )
  }
  
  public func apply(_ snapshot: DiffableDataSourceSnapshot<Section, Item>) {
    dataSource.apply(snapshot)
  }
  
  public func snapshot() -> DiffableDataSourceSnapshot<Section, Item> {
    dataSource.currentSnapshot
  }
  
  public typealias 
  Registration<CellType: UICollectionViewCell> = UICollectionView
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

public struct 
DiffableDataSourceSnapshot<Section: Identifiable, Item: Hashable> {
  public private(set) var sectionIdentifiers = [Section]()
  internal var sections = [Section.ID]()
  internal var items = [Section.ID: [Item]]()
  private var sectionsSeen = Set<Section.ID>()
  private var itemsSeen = [Section.ID:Set<Int>]()
  
  public init() {
    self.sectionIdentifiers = .init()
    self.sections = .init()
    self.items = .init()
  }
  
  public mutating func appendSections(_ sections: [Section]) {
    for section in sections {
      if sectionsSeen.insert(section.id).inserted {
        self.sections.append(section.id)
        self.sectionIdentifiers.append(section)
      }
    }
  }
  
  public mutating func appendItems(
    _ items: [Item],
    toSection section: Section
  ) {
    for item in items {
      if itemsSeen[section.id, default: []].insert(item.hashValue).inserted {
        self.items[section.id, default: []].append(item)
      }
    }
  }
  
  public mutating func deleteItems(
    _ items: [Item],
    inSection section: Section
  ) {
    self.items[section.id]!.removeAll(where: items.contains)
    self.itemsSeen[section.id]?.subtract(items.map(\.hashValue))
  }
  
  public mutating func reset() {
    self = .init()
  }
  
  internal func accumulateDifference(
    into snapshot: inout DiffableDataSourceSnapshot
  ) -> Changes {
    var changes = Changes(.init(), .init(), .init(), .init())
    let sectionDifference = self.sections.difference(from: snapshot.sections)
    defer {
      snapshot.sections = snapshot
        .sections
        .applying(sectionDifference) ?? []
      snapshot.sectionIdentifiers = sectionIdentifiers
      snapshot.itemsSeen = itemsSeen
      snapshot.sectionsSeen = sectionsSeen
    }
    
    for change in sectionDifference {
      switch change {
      case let .remove(offset, _, _):
        changes.sectionRemovals.insert(offset)
      case let .insert(offset, element, _):
        changes.sectionInsertions.insert(offset)
        if let items = items[element] {
          snapshot.items[element] = items
          changes.itemInsertions.formUnion(
            items.indices.map { IndexPath(row: $0, section: offset) }
          )
        }
      }
    }
    
    for section in sections {
      guard
        let currentItems = snapshot.items[section],
        let difference = items[section]?.difference(from: currentItems)
      else { continue }
      defer {
        snapshot.items[section] = currentItems.applying(difference)
      }
      for change in difference {
        switch change {
        case let .remove(offset, _, _):
          changes.itemRemovals.insert(
            IndexPath(
              row: offset,
              section: snapshot.sections.firstIndex(of: section)!
            )
          )
        case let .insert(offset, _, _):
          changes.itemInsertions.insert(
            IndexPath(
              row: offset,
              section: sections.firstIndex(of: section)!
            )
          )
        }
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

extension DiffableDataSourceSnapshot: Sendable
where
Section: Sendable,
Section.ID: Sendable,
Item: Sendable {}

internal extension DiffableDataSource {
  private final class _DataSource:
    NSObject, UICollectionViewDataSource, Sendable
  {
    var currentSnapshot = DiffableDataSourceSnapshot<Section, Item>()
    let cellProvider: CellProvider
    let collectionView: UICollectionView
    
    init(
      collectionView: UICollectionView,
      initial: DiffableDataSourceSnapshot<Section, Item>,
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
      currentSnapshot.items[currentSnapshot.sections[section]]?.count ?? 0
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
    
    func apply(_ snapshot: DiffableDataSourceSnapshot<Section, Item>) {
      collectionView.performBatchUpdates { [unowned self] in
        let changes = snapshot.accumulateDifference(into: &currentSnapshot)
        collectionView.deleteSections(changes.sectionRemovals)
        collectionView.insertSections(changes.sectionInsertions)
        collectionView.deleteItems(at: Array(changes.itemRemovals))
        collectionView.insertItems(at: Array(changes.itemInsertions))
      }
    }
  }
}
