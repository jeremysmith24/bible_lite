//
//  bible_lite_xcodeprojApp.swift
//  bible_lite.xcodeproj
//
//  Created by Jeremy Smith on 6/2/26.
//

import SwiftUI

@main
struct bible_lite_xcodeprojApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                BookListView()
                    .tabItem {
                        Label("Read", systemImage: "book")
                    }
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
            }
        }
    }
}
