import AppKit
import Defaults
import Fuse
import Foundation

class Search {
  enum Mode: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
    case exact
    case fuzzy
    case regexp
    case mixed

    var id: Self { self }

    var description: String {
      switch self {
      case .exact:
        return NSLocalizedString("Exact", tableName: "GeneralSettings", comment: "")
      case .fuzzy:
        return NSLocalizedString("Fuzzy", tableName: "GeneralSettings", comment: "")
      case .regexp:
        return NSLocalizedString("Regex", tableName: "GeneralSettings", comment: "")
      case .mixed:
        return NSLocalizedString("Mixed", tableName: "GeneralSettings", comment: "")
      }
    }
  }

  struct SearchResult: Equatable {
    var score: Double?
    var object: Searchable
    var ranges: [Range<String.Index>] = []
  }

  typealias Searchable = HistoryItemDecorator

  private let fuse = Fuse(threshold: 0.7) // threshold found by trial-and-error
  private let fuzzySearchLimit = 5_000

  func search(string: String, within: [Searchable]) -> [SearchResult] {
    guard !string.isEmpty else {
      return within.map { SearchResult(object: $0) }
    }

    switch Defaults[.searchMode] {
    case .mixed:
      return mixedSearch(string: string, within: within)
    case .regexp:
      return simpleSearch(string: string, within: within, options: .regularExpression)
    case .fuzzy:
      return fuzzySearch(string: string, within: within)
    default:
      return simpleSearch(string: string, within: within, options: .caseInsensitive)
    }
  }

  private func fuzzySearch(string: String, within: [Searchable]) -> [SearchResult] {
    let pattern = fuse.createPattern(from: string)
    let searchResults: [SearchResult] = within.compactMap { item in
      fuzzySearch(for: pattern, in: item.title, of: item)
    }
    let sortedResults = searchResults.sorted(by: { ($0.score ?? 0) < ($1.score ?? 0) })
    return sortedResults
  }

  private func fuzzySearch(
    for pattern: Fuse.Pattern?,
    in searchString: String,
    of item: Searchable
  ) -> SearchResult? {
    var searchString = searchString
    if searchString.count > fuzzySearchLimit {
      // shortcut to avoid slow search
      let stopIndex = searchString.index(searchString.startIndex, offsetBy: fuzzySearchLimit)
      searchString = "\(searchString[...stopIndex])"
    }

    if let fuzzyResult = fuse.search(pattern, in: searchString) {
      return SearchResult(
        score: fuzzyResult.score,
        object: item,
        ranges: fuzzyResult.ranges.map {
          let startIndex = searchString.startIndex
          let lowerBound = searchString.index(startIndex, offsetBy: $0.lowerBound)
          let upperBound = searchString.index(startIndex, offsetBy: $0.upperBound + 1)

          return lowerBound..<upperBound
        }
      )
    } else {
      return nil
    }
  }

  private func simpleSearch(
    string: String,
    within: [Searchable],
    options: NSString.CompareOptions
  ) -> [SearchResult] {
      let totalSize = within.compactMap({ $0.title.count }).reduce(0, +);
      let totalCount = within.count;
      NSLog("Maccy845 new search, query char count: \(string.count)");
      NSLog("Maccy845 totalSize: \(totalSize) totalCount: \(totalCount)")
      
      var ts = Date().timeIntervalSince1970;
      let StringRes = within.compactMap { simpleSearch(for: string, in: $0.title, of: $0, options: options, algo: "String") };
      let StringDuration = Date().timeIntervalSince1970-ts;
      NSLog("""
      Maccy845 StringDuration: \(String(format: "%5.3f", StringDuration)) StringFound: \(StringRes.count)
""")
      
      ts = Date().timeIntervalSince1970;
      let NSStringRes = within.compactMap { simpleSearch(for: string, in: $0.title, of: $0, options: options, algo: "NSString") };
      let NSStringDuration = Date().timeIntervalSince1970-ts;
      NSLog("""
      Maccy845 NSStringDuration: \(String(format: "%5.3f", NSStringDuration))  NSStringFound: \(NSStringRes.count)
""")
      NSLog("--------------------")
      return NSStringRes
  }

  private func simpleSearch(
    for string: String,
    in searchString: String,
    of item: Searchable,
    options: NSString.CompareOptions,
    algo: String = "String"
  ) -> SearchResult? {
      let ts = Date().timeIntervalSince1970;
      var range: Range<String.Index>? = nil;
      if algo == "String" {
          range = searchString.range(of: string, options: options);
          
          if  range != nil {
              return SearchResult(object: item, ranges: Array([range!]))
          } else {
              return nil
            }
      } else {
          let trange = NSString(string: searchString).range(of: string, options: options);
          
          if  trange.location != NSNotFound {
              return SearchResult(object: item, ranges: Array([Range(trange, in: searchString)!]))
          } else {
              return nil
            }
      }
//      print(searchString.count, "  String", Date().timeIntervalSince1970-ts)
      
  }

  private func mixedSearch(string: String, within: [Searchable]) -> [SearchResult] {
    var results = simpleSearch(string: string, within: within, options: .caseInsensitive)
    guard results.isEmpty else {
      return results
    }

    results = simpleSearch(string: string, within: within, options: .regularExpression)
    guard results.isEmpty else {
      return results
    }

    results = fuzzySearch(string: string, within: within)
    guard results.isEmpty else {
      return results
    }

    return []
  }
}
