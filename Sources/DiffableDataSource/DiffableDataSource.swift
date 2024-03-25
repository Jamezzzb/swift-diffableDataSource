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
  
  public func sectionIdentifier(for index: Int) -> Section? {
    dataSource.currentSnapshot.sectionIdentifier(for: index)
  }
  
  public func index(for sectionIdentifier: Section) -> Int? {
    dataSource.currentSnapshot.index(for: sectionIdentifier)
  }
  
  public func itemIdentifier(for indexPath: IndexPath) -> Item? {
    dataSource.currentSnapshot.itemIdentifier(for: indexPath)
  }
  
  public func indexPath(for itemIdentifier: Item) -> IndexPath? {
    dataSource.currentSnapshot.indexPath(for: itemIdentifier)
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
  private var itemsSeen = Set<Int>()
  
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
      if itemsSeen.insert(item.hashValue).inserted {
        self.items[section.id, default: []].append(item)
      }
    }
  }
  
  public mutating func deleteItems(
    _ items: [Item],
    fromSection section: Section
  ) {
    self.items[section.id]?.removeAll(where: items.contains)
    self.itemsSeen.subtract(items.map(\.hashValue))
  }
  
  public mutating func reset() {
    self = .init()
  }
  
  internal func sectionIdentifier(for index: Int) -> Section? {
    guard
      sectionIdentifiers.indices.contains(index)
    else { return nil }
    return sectionIdentifiers[index]
  }
  
  internal func index(for sectionIdentifier: Section) -> Int? {
    sections.firstIndex(of: sectionIdentifier.id)
  }
  
  internal func itemIdentifier(for indexPath: IndexPath) -> Item? {
    guard
      sections.indices.contains(indexPath.section),
      let items = items[sections[indexPath.section]],
      items.indices.contains(indexPath.row)
    else {
      assertionFailure()
      return nil
    }
    return items[indexPath.row]
  }
  
  internal func indexPath(for itemIdentifier: Item) -> IndexPath? {
    items.first(where: {
      $0.value.contains(itemIdentifier)
    }).map {
      IndexPath(
        row:
          items[$0.key]!.firstIndex(of: itemIdentifier)!,
        section: sections.firstIndex(of: $0.key)!
      )
    }
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

private extension DiffableDataSource {
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
