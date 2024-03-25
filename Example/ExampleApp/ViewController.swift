import UIKit
import DiffableDataSource

class ViewController: UIViewController {
  var dataSource: DiffableDataSource<Section, Int>!
  var updateTask: Task<(), Never>?
  enum Section: Int, Identifiable {
    case main
    var id: Int { rawValue }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    let collectionView = UICollectionView(
      frame: view.bounds,
      collectionViewLayout: makeLayout()
    )
    view.addSubview(collectionView)
    let cellRegistration = DiffableDataSource<Section, Int>
      .Registration<UICollectionViewListCell> { cell, indexPath, identifier in
        var configuration = cell.defaultContentConfiguration()
        configuration.text = String(identifier)
        configuration.image = UIImage(systemName: "star")
        cell.contentConfiguration = configuration
      }
    var snapshot = DiffableSnapshot<Section, Int>()
    snapshot.appendSections([.main])
    snapshot.appendItems([1, 2, 3], toSection: .main)
    dataSource = DiffableDataSource(
      collectionView: collectionView,
      initial: snapshot
    ) { collectionView, indexPath, item in
      collectionView.dequeueConfiguredReusableCell(
        using: cellRegistration,
        for: indexPath,
        item: item
      )
    }
    configureButtons()
  }
  
  func configureButtons() {
    let button = UIBarButtonItem()
    button.style = .plain
    button.primaryAction = .init(
      title: "Start"
    ) { [unowned self] _ in
      toggleUpdateTask()
      button.title = updateTask?.isCancelled != false ? "Start" : "Stop"
    }
    navigationItem.rightBarButtonItem = button
    let goToSortingDemoButton = UIBarButtonItem()
    goToSortingDemoButton.style = .plain
    goToSortingDemoButton.primaryAction = .init(
      title: "GoTo Sorting Demo"
    ) { [unowned self] _ in
      updateTask?.cancel()
      button.title = "Start"
      navigationController?.pushViewController(
        InsertionSortViewController(),
        animated: true
      )
    }
    navigationItem.leftBarButtonItem = goToSortingDemoButton
  }
  
  func toggleUpdateTask() {
    if updateTask == nil {
      // initial data
      dataSource.apply(randomSnapshot())
      updateTask = Task { @MainActor [unowned self] in
        defer { updateTask = nil }
        await updateEachSecond()
      }
    } else {
      updateTask?.cancel()
    }
  }
  
  func randomSnapshot() -> DiffableSnapshot<Section, Int> {
    var snapshot = DiffableSnapshot<Section, Int>()
    snapshot.appendSections([.main])
    var numbers = [Int]()
    (0..<49).forEach { _ in
      numbers.append(Int.random(in: 0..<99))
    }
    snapshot.appendItems(numbers, toSection: .main)
    return snapshot
  }
  
  // for simulating changes
  @MainActor func updateEachSecond() async {
    let stream = AsyncStream { [unowned self] in
      do {
        try await Task.sleep(for: .seconds(1))
        return randomSnapshot()
      } catch {
        return nil
      }
    }
    
    for await snapshot in stream {
      dataSource.apply(snapshot)
    }
  }
  
  private func makeLayout() -> UICollectionViewLayout {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(0.2),
      heightDimension: .fractionalHeight(1.0)
    )
    let item = NSCollectionLayoutItem(
      layoutSize: itemSize
    )
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .fractionalWidth(0.2)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupSize,
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    let layout = UICollectionViewCompositionalLayout(section: section)
    return layout
  }
}

