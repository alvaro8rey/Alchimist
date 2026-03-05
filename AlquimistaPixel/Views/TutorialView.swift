import SwiftUI

struct TutorialView: View {
    @Binding var isPresented: Bool
    @AppStorage("tutorialDone") private var tutorialDone = false
    @State private var currentStep = 0
    @State private var pulsing = false
    @State private var elementsOffset: CGFloat = 0

    private struct Step {
        let icon: String
        let title: String
        let description: String
    }

    private let steps: [Step] = [
        Step(
            icon: "👆",
            title: "Añade elementos",
            description: "Toca cualquier elemento de la barra inferior para añadirlo al canvas."
        ),
        Step(
            icon: "⚗️",
            title: "Combínalos",
            description: "Arrastra un elemento encima de otro.\nLa IA genera algo que quizás nadie ha visto."
        ),
        Step(
            icon: "🌟",
            title: "¡Sé el primero!",
            description: "Si eres el primero en el mundo en hacer esa combinación, ¡apareces en el feed global!"
        )
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Card principal
                VStack(spacing: 28) {

                    // Icono animado
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.06))
                            .frame(width: 110, height: 110)
                        Circle()
                            .strokeBorder(.white.opacity(pulsing ? 0.2 : 0.06), lineWidth: 1.5)
                            .frame(width: pulsing ? 130 : 110, height: pulsing ? 130 : 110)
                            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulsing)
                        Text(steps[currentStep].icon)
                            .font(.system(size: 54))
                            .scaleEffect(pulsing ? 1.08 : 0.96)
                            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulsing)
                    }

                    // Textos
                    VStack(spacing: 10) {
                        Text(steps[currentStep].title)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(steps[currentStep].description)
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 8)

                    // Visual específico por paso
                    Group {
                        if currentStep == 0 { inventoryHint }
                        else if currentStep == 1 { combinePreview }
                        else { discoveryToast }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id(currentStep)

                    // Dots indicadores
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentStep ? .white : .white.opacity(0.25))
                                .frame(width: i == currentStep ? 20 : 6, height: 6)
                                .animation(.spring(response: 0.3), value: currentStep)
                        }
                    }

                    // Botón principal
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if currentStep < steps.count - 1 {
                                currentStep += 1
                            } else {
                                tutorialDone = true
                                isPresented = false
                            }
                        }
                    } label: {
                        Text(currentStep < steps.count - 1 ? "Siguiente" : "¡A descubrir!")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                            )
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color(red: 2/255, green: 6/255, blue: 23/255))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                Spacer()

                // Saltar
                Button {
                    tutorialDone = true
                    isPresented = false
                } label: {
                    Text("Saltar")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.bottom, 44)
            }
        }
        .onAppear { pulsing = true }
    }

    // MARK: - Visuales por paso

    private var inventoryHint: some View {
        HStack(spacing: 10) {
            ForEach(["🔥", "💧", "🌍", "💨"], id: \.self) { emoji in
                VStack(spacing: 4) {
                    Text(emoji)
                        .font(.system(size: 28))
                }
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(pulsing ? 0.35 : 0.1), lineWidth: 1.5)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulsing)
        )
    }

    private var combinePreview: some View {
        HStack(spacing: 8) {
            miniElement(emoji: "🔥", offset: elementsOffset)
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
            miniElement(emoji: "💧", offset: -elementsOffset)
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.06))
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    )
                Text("?")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                elementsOffset = 5
            }
        }
    }

    private var discoveryToast: some View {
        HStack(spacing: 10) {
            Text("🌟")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("¡Primer descubrimiento mundial!")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Dragón de Vapor")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .scaleEffect(pulsing ? 1.02 : 0.98)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulsing)
    }

    private func miniElement(emoji: String, offset: CGFloat) -> some View {
        Text(emoji)
            .font(.system(size: 28))
            .frame(width: 52, height: 52)
            .background(.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .offset(x: offset)
    }
}
