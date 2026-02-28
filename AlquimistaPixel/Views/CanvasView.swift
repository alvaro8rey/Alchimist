import SwiftUI

struct CanvasView: View {
    @ObservedObject var vm: CanvasViewModel
    @Binding var screenSize: CGSize
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var showHistory = false
    @State private var showClearAlert = false
    @State private var showProfile = false
    @State private var showLeaderboard = false
    @State private var showFeed = false

    var currentOffset: CGSize {
        CGSize(
            width: vm.canvasOffset.width + dragTranslation.width,
            height: vm.canvasOffset.height + dragTranslation.height
        )
    }

    // screenPos(P) = P * scale + screenCenter + canvasOffset
    func screenX(_ worldX: CGFloat, width: CGFloat) -> CGFloat {
        worldX * vm.scale + width / 2 + currentOffset.width
    }
    func screenY(_ worldY: CGFloat, height: CGFloat) -> CGFloat {
        worldY * vm.scale + height / 2 + currentOffset.height
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 2/255, green: 6/255, blue: 23/255).ignoresSafeArea()

                InfiniteGridView(offset: currentOffset, scale: vm.scale)

                // Gesto de paneo del canvas (fondo)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .updating($dragTranslation) { value, state, _ in
                                if vm.draggingElementID == nil { state = value.translation }
                            }
                            .onEnded { value in
                                if vm.draggingElementID == nil {
                                    vm.canvasOffset.width += value.translation.width
                                    vm.canvasOffset.height += value.translation.height
                                }
                            }
                    )

                // Elementos: ZStack con frame explícito para posicionamiento predecible
                ZStack {
                    ForEach(vm.activeElements) { element in
                        ElementView(
                            element: element,
                            isDragging: vm.draggingElementID == element.id,
                            isHighlighted: vm.highlightedElementID == element.id
                        )
                        .scaleEffect(vm.scale)
                        .position(
                            x: screenX(element.position.x, width: geo.size.width),
                            y: screenY(element.position.y, height: geo.size.height)
                        )
                        .onTapGesture(count: 2) {
                            vm.duplicateElement(element)
                        }
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    if vm.draggingElementID == nil {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        vm.draggingElementID = element.id
                                        vm.dragStartWorldPosition = element.position
                                    }
                                    if let start = vm.dragStartWorldPosition {
                                        let dx = value.translation.width / vm.scale
                                        let dy = value.translation.height / vm.scale
                                        vm.updatePosition(for: element.id, to: CGPoint(x: start.x + dx, y: start.y + dy))
                                    }
                                }
                                .onEnded { _ in
                                    vm.handleElementDrop(id: element.id, screenSize: geo.size)
                                }
                        )
                        .zIndex(vm.draggingElementID == element.id ? 100 : 0)
                    }

                    // Spinner de carga mientras la IA genera la combinación
                    if let pos = vm.combiningPosition {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.3)
                            .position(
                                x: screenX(pos.x, width: geo.size.width),
                                y: screenY(pos.y, height: geo.size.height)
                            )
                            .transition(.opacity)
                    }

                    // Estado vacío
                    if vm.activeElements.isEmpty && vm.combiningPosition == nil {
                        VStack(spacing: 8) {
                            Text("Toca un elemento del inventario para añadirlo")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: 240)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 - 60)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: vm.combiningPosition == nil)
                .frame(width: geo.size.width, height: geo.size.height)

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
            .onAppear {
                screenSize = geo.size
                vm.resetCamera(screenSize: geo.size)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { header }
        .sheet(isPresented: $showHistory) {
            CombinationHistoryView(history: vm.combinationHistory)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showFeed) {
            GlobalFeedView()
                .preferredColorScheme(.dark)
        }
        .alert("Limpiar canvas", isPresented: $showClearAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Limpiar", role: .destructive) { vm.clearCanvas() }
        } message: {
            Text("Se eliminarán todos los elementos del canvas. Tu inventario no cambiará.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Chromancy")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 6) {
                // Zoom controls
                zoomButton(icon: "minus", action: vm.zoomOut)
                zoomButton(icon: "plus", action: vm.zoomIn)
                zoomButton(icon: "scope") { vm.resetCamera(screenSize: screenSize) }

                // Menú con el resto de acciones
                Menu {
                    Button { showProfile = true } label: {
                        Label("Perfil", systemImage: "person.circle")
                    }
                    Button { showLeaderboard = true } label: {
                        Label("Ranking global", systemImage: "trophy")
                    }
                    Button { showFeed = true } label: {
                        Label("Descubrimientos", systemImage: "globe")
                    }
                    if !vm.combinationHistory.isEmpty {
                        Button { showHistory = true } label: {
                            Label("Historial", systemImage: "clock.arrow.circlepath")
                        }
                    }
                    if !vm.activeElements.isEmpty {
                        Divider()
                        Button(role: .destructive) { showClearAlert = true } label: {
                            Label("Limpiar canvas", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
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
