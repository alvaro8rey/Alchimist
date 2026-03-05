import SwiftUI

struct AuthView: View {
    let onComplete: ([UserService.InventoryItem]) -> Void

    private enum AuthMode { case register, login }
    private enum Field { case username, password, confirmPassword }

    @State private var mode: AuthMode = .register
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focused: Field?
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let userService = UserService()

    private var canSubmit: Bool {
        let u = username.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty, password.count >= 4 else { return false }
        if mode == .register { return password == confirmPassword }
        return true
    }

    private func playAsGuest() {
        userService.enterGuestMode()
        onComplete([])
    }

    private func submit() {
        guard canSubmit, !isLoading else { return }
        let name = username.trimmingCharacters(in: .whitespaces)
        Task {
            isLoading = true
            errorMessage = nil
            do {
                if mode == .register {
                    let taken = await userService.isUsernameTaken(name)
                    if taken {
                        await MainActor.run {
                            errorMessage = "Ese nombre ya está en uso. ¡Elige otro!"
                            isLoading = false
                        }
                        return
                    }
                    try await userService.register(username: name, password: password)
                    await MainActor.run { isLoading = false; onComplete([]) }
                } else {
                    let inventory = try await userService.login(username: name, password: password)
                    await MainActor.run { isLoading = false; onComplete(inventory) }
                }
            } catch let e as AuthError {
                await MainActor.run { errorMessage = e.errorDescription; isLoading = false }
            } catch {
                await MainActor.run { errorMessage = "Error de conexión. Intenta de nuevo."; isLoading = false }
            }
        }
    }

    var body: some View {
        ZStack {
            Color(red: 2/255, green: 6/255, blue: 23/255).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("⚗️").font(.system(size: 72))
                    Text("Chromancy")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Combina elementos, descubre el mundo")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 20) {
                    // Selector de modo
                    HStack(spacing: 0) {
                        modeButton("Nueva cuenta", for: .register)
                        modeButton("Ya tengo cuenta", for: .login)
                    }
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Campos
                    VStack(spacing: 10) {
                        TextField("Nombre de alquimista...", text: $username)
                            .styledField()
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focused, equals: .username)
                            .onAppear { focused = .username }
                            .submitLabel(.next)
                            .onSubmit { focused = .password }
                            .onChange(of: username) { _, _ in errorMessage = nil }

                        SecureField("Contraseña (mín. 4 caracteres)...", text: $password)
                            .styledField()
                            .focused($focused, equals: .password)
                            .submitLabel(mode == .register ? .next : .go)
                            .onSubmit { if mode == .register { focused = .confirmPassword } else { submit() } }
                            .onChange(of: password) { _, _ in errorMessage = nil }

                        if mode == .register {
                            SecureField("Confirmar contraseña...", text: $confirmPassword)
                                .styledField(
                                    borderColor: (!confirmPassword.isEmpty && confirmPassword != password)
                                        ? .red.opacity(0.6)
                                        : .white.opacity(0.15)
                                )
                                .focused($focused, equals: .confirmPassword)
                                .submitLabel(.go)
                                .onSubmit { submit() }
                                .onChange(of: confirmPassword) { _, _ in errorMessage = nil }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: mode)
                    .animation(.easeInOut(duration: 0.2), value: errorMessage)

                    // Botón principal
                    Button { submit() } label: {

                        Group {
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                    Text(mode == .register ? "Creando cuenta..." : "Entrando...")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            } else {
                                Text(mode == .register ? "Empezar a descubrir" : "Entrar")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background((canSubmit && !isLoading) ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    (canSubmit && !isLoading) ? .white.opacity(0.25) : .white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .disabled(!canSubmit || isLoading)
                    .animation(.easeInOut(duration: 0.15), value: isLoading)

                    Button { playAsGuest() } label: {
                        Text("Continuar sin cuenta")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 60)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func modeButton(_ label: String, for target: AuthMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = target
                errorMessage = nil
                confirmPassword = ""
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: mode == target ? .semibold : .regular))
                .foregroundStyle(mode == target ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(mode == target ? .white.opacity(0.12) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(3)
    }
}

// MARK: - View modifier para campos de texto

private extension View {
    func styledField(borderColor: Color = .white.opacity(0.15)) -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 17))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }
}
