import SwiftUI

struct CanvasView: View {
    @ObservedObject var vm: CanvasViewModel
    @Binding var screenSize: CGSize
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var activePinchScale: CGFloat = 1.0

    var currentOffset: CGSize {
        CGSize(
            width: vm.canvasOffset.width + dragTranslation.width,
            height: vm.canvasOffset.height + dragTranslation.height
        )
    }

    var effectiveScale: CGFloat {
        min(4.0, max(0.2, vm.scale * activePinchScale))
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // FONDO: Si da error 'hex:', asegúrate de haber creado el archivo Color+Hex.swift
                Color(hex: "#020617").ignoresSafeArea()
                
                InfiniteGridView(offset: currentOffset, scale: vm.scale)
                
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .updating($dragTranslation) { value, state, _ in
                                    if vm.draggingElementID == nil { state = value.translation }
                                }
                                .onEnded { value in
                                    if vm.draggingElementID == nil {
                                        vm.canvasOffset.width += value.translation.width
                                        vm.canvasOffset.height += value.translation.height
                                    }
                                },
                            MagnificationGesture()
                                .updating($activePinchScale) { value, state, _ in
                                    state = value
                                }
                                .onEnded { value in
                                    vm.commitPinch(value)
                                }
                        )
                    )
                
                ZStack {
                    ForEach(vm.activeElements) { element in
                        ElementView(
                            element: element,
                            isDragging: vm.draggingElementID == element.id,
                            isHighlighted: vm.highlightedElementID == element.id
                        )
                        .position(x: element.position.x, y: element.position.y)
                        .onTapGesture(count: 2) {
                            vm.duplicateElement(element)
                        }
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    if vm.draggingElementID == nil {
                                        vm.draggingElementID = element.id
                                        vm.dragStartWorldPosition = element.position
                                    }
                                    if let start = vm.dragStartWorldPosition {
                                        let dx = value.translation.width / effectiveScale
                                        let dy = value.translation.height / effectiveScale
                                        vm.updatePosition(for: element.id, to: CGPoint(x: start.x + dx, y: start.y + dy))
                                    }
                                }
                                .onEnded { _ in
                                    vm.handleElementDrop(id: element.id, screenSize: geo.size)
                                }
                        )
                        .zIndex(vm.draggingElementID == element.id ? 100 : 0)
                    }
                }
                .scaleEffect(effectiveScale)
                .offset(currentOffset)
                
                // PAPELERA
                VStack {
                    Spacer()
                    HStack {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 60, height: 60)
                                .overlay(Circle().stroke(vm.draggingElementID != nil ? Color.red : Color.white.opacity(0.2), lineWidth: 2))
                            
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundStyle(vm.draggingElementID != nil ? .red : .white.opacity(0.6))
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 160)
                        Spacer()
                    }
                }
            }
            .onAppear { screenSize = geo.size }
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { header }
    }
    
    private var header: some View {
        HStack(alignment: .center) {
            Text("Chromancy")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
            
            HStack(spacing: 8) {
                zoomButton(icon: "minus", action: vm.zoomOut)
                zoomButton(icon: "plus", action: vm.zoomIn)
                zoomButton(icon: "scope", action: { vm.resetCamera(screenSize: screenSize) })
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
        .padding(.bottom, 10)
        .background(LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
    }
    
    private func zoomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.1))
                .clipShape(Circle())
        }
    }
}

// ESTO DEBE ESTAR AQUÍ PARA QUE NO DE ERROR DE SCOPE
struct InfiniteGridView: View {
    let offset: CGSize
    let scale: CGFloat
    
    var body: some View {
        Canvas { ctx, size in
            let step = 40.0 * scale
            let xOffset = offset.width.truncatingRemainder(dividingBy: step)
            let yOffset = offset.height.truncatingRemainder(dividingBy: step)
            
            for x in stride(from: xOffset - step, to: size.width + step, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1)
            }
            for y in stride(from: yOffset - step, to: size.height + step, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}
