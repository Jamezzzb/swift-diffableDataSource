/*
 Apple, iPhone, iMac, iPad Pro, Apple Pencil, Apple Watch, App Store, TestFlight, Siri, and SiriKit are trademarks of Apple, Inc.

 The following license applies to the source code, and other elements of this package:

 Copyright © 2023 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Abstract:
`InsertionSortArray` provides a self sorting array class
*/

import UIKit

class InsertionSortArray: Hashable, Identifiable {

    struct SortNode: Hashable {
        let value: Int
        let color: UIColor

        init(value: Int, maxValue: Int) {
            self.value = value
            let hue = CGFloat(value) / CGFloat(maxValue)
            self.color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        }
        private let identifier = UUID()
        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
        }
        static func == (lhs: SortNode, rhs: SortNode) -> Bool {
            return lhs.identifier == rhs.identifier
        }
    }
    var values: [SortNode] {
        return nodes
    }
    var isSorted: Bool {
        return isSortedInternal
    }
    func sortNext() {
        performNextSortStep()
    }
    init(count: Int) {
        nodes = (0..<count).map { SortNode(value: $0, maxValue: count) }.shuffled()
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    static func == (lhs: InsertionSortArray, rhs: InsertionSortArray) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    private var identifier = UUID()
    private var currentIndex = 1
    private var isSortedInternal = false
    private var nodes: [SortNode]
}

extension InsertionSortArray {
    fileprivate func performNextSortStep() {
        if isSortedInternal {
            return
        }
        if nodes.count == 1 {
            isSortedInternal = true
            return
        }

        var index = currentIndex
        let currentNode = nodes[index]
        index -= 1
        while index >= 0 && currentNode.value < nodes[index].value {
            let tmp = nodes[index]
            nodes[index] = currentNode
            nodes[index + 1] = tmp
            index -= 1
        }
        currentIndex += 1
        if currentIndex >= nodes.count {
            isSortedInternal = true
        }
    }
}
