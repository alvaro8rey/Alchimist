import SwiftUI

struct OnboardingView: View {
    let onComplete: (String) -> Void
    @State private var username = ""
    @FocusState private var focused: Bool

    private var isValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
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
                                .strokeBorder(.white.opacity(isValid ? 0.3 : 0.12), lineWidth: 1)
                        )
                        .focused($focused)
                        .onAppear { focused = true }
                        .submitLabel(.go)
                        .onSubmit {
                            if isValid { onComplete(username.trimmingCharacters(in: .whitespaces)) }
                        }

                    Button {
                        if isValid { onComplete(username.trimmingCharacters(in: .whitespaces)) }
                    } label: {
                        Text("Empezar a descubrir")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(isValid ? .white.opacity(0.25) : .white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .disabled(!isValid)
                    .animation(.easeInOut(duration: 0.15), value: isValid)
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 60)
            }
        }
        .preferredColorScheme(.dark)
    }
}
