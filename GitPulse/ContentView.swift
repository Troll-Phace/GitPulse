//  ContentView.swift
//  GitPulse
//
//  Created by Anthony Grimaldi on 4/12/26.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationSplitView {
      List {
        Text("GitPulse")
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
      Text("Select an item")
    }
  }
}

#Preview {
  ContentView()
}
