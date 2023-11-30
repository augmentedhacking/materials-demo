//
//  ContentView.swift
//  MaterialsDemo
//
//  Created by Nien Lam on 11/1/23.
//  Copyright © 2023 Line Break, LLC. All rights reserved.
//

import SwiftUI

// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            // AR View.
            ARViewContainer(viewModel: viewModel)
            
            VStack {
                Spacer()
                
                HStack {
                    VStack {
                        Spacer()
                        filterButton()
                        lockButton()
                    }
                    
                    Spacer()
                    
                    VStack {
                        Spacer()
                        lightButton()
                        sphereButton()
                        boardButton()
                        chairButton()
                    }
                }
            }
            .padding()
        }
    }
    
    func lockButton() -> some View {
        Button {
            viewModel.positionIsLocked.toggle()
        } label: {
            Label("Lock Position", systemImage: "target")
                .font(.system(.title))
                .foregroundColor(viewModel.positionIsLocked ? .yellow : .white)
                .labelStyle(IconOnlyLabelStyle())
                .frame(width: 44, height: 44)
        }
    }
    
    func lightButton() -> some View {
        Button {
            viewModel.directionalLightEnabled.toggle()
        } label: {
            Label("Light", systemImage: "light.overhead.left.fill")
                .font(.system(.title))
                .foregroundColor(viewModel.directionalLightEnabled ? .yellow : .white)
                .labelStyle(IconOnlyLabelStyle())
                .frame(width: 44, height: 44)
        }
    }
    
    func sphereButton() -> some View {
        Button {
            viewModel.sphereEnabled.toggle()
        } label: {
            Label("Spheres", systemImage: "circle")
                .font(.system(.title))
                .foregroundColor(viewModel.sphereEnabled ? .yellow : .white)
                .labelStyle(IconOnlyLabelStyle())
                .frame(width: 44, height: 44)
        }
    }
    
    func boardButton() -> some View {
        Button {
            viewModel.boardEnabled.toggle()
        } label: {
            Label("Board", systemImage: "rectangle.checkered")
                .font(.system(.title))
                .foregroundColor(viewModel.boardEnabled ? .yellow : .white)
                .labelStyle(IconOnlyLabelStyle())
                .frame(width: 44, height: 44)
        }
    }
    
    func chairButton() -> some View {
        Button {
            viewModel.chairEnabled.toggle()
        } label: {
            Label("Chair", systemImage: "chair")
                .font(.system(.title))
                .foregroundColor(viewModel.chairEnabled ? .yellow : .white)
                .labelStyle(IconOnlyLabelStyle())
                .frame(width: 44, height: 44)
        }
    }
    
    func filterButton() -> some View {
        Button {
            // Cycle filters.
            viewModel.filtersIdx = (viewModel.filtersIdx + 1) % 6
        } label: {
            Label("Filters", systemImage: "camera.filters")
                .font(.system(.title))
                .foregroundColor(viewModel.filtersIdx != 0 ? .yellow : .white)
                .labelStyle(IconOnlyLabelStyle())
                .frame(width: 44, height: 44)
        }
    }
}

