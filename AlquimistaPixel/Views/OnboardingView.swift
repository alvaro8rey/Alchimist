import SwiftUI

struct OnboardingView: View {
    let onComplete: (String) -> Void
    @State private var username = ""
    @FocusState private var focused: Bool
    @State private var isChecking = false
    @State private var errorMessage: String? = nil
    private let userService = UserService()

    private var isValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func trySubmit() {
        guard isValid, !isChecking else { return }
        let name = username.trimmingCharacters(in: .whitespaces)
        Task {
            isChecking = true
            errorMessage = nil
            let taken = await userService.isUsernameTaken(name)
            isChecking = false
            if taken {
                errorMessage = "Ese nombre ya está en uso. ¡Elige otro!"
            } else {
                onComplete(name)
            }
        }
    }

    var body: some View {
        ZStack {
            Color(red: 2/255, green: 6/255, blue: 23/255).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("⚗️")
                        .font(.system(size: 72))
                    Text("Chromancy")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Combina elementos, descubre el mundo")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 14) {
                    Text("¿Cómo te llamas?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)

                    VStack(spacing: 8) {
                        TextField("Tu nombre de alquimista...", text: $username)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        errorMessage != nil
                                            ? Color.red.opacity(0.7)
                                            : .white.opacity(isValid ? 0.3 : 0.12),
                                        lineWidth: 1
                                    )
                            )
                            .focused($focused)
                            .onAppear { focused = true }
                            .submitLabel(.go)
                            .onSubmit { trySubmit() }
                            .onChange(of: username) { _, _ in errorMessage = nil }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: errorMessage)

                    Button { trySubmit() } label: {
                        Group {
                            if isChecking {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                    Text("Comprobando...")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            } else {
                                Text("Empezar a descubrir")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background((isValid && !isChecking) ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    (isValid && !isChecking) ? .white.opacity(0.25) : .white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .disabled(!isValid || isChecking)
                    .animation(.easeInOut(duration: 0.15), value: isChecking)
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 60)
            }
        }
        .preferredColorScheme(.dark)
    }
}
