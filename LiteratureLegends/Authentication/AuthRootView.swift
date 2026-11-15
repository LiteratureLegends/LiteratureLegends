
import SwiftUI

struct AuthRootView: View {
    @StateObject private var auth = AuthManager()

    var body: some View {
        Group {
            if auth.isCheckingSession {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Checking your account…")
                        .foregroundStyle(.secondary)
                }
            } else if let user = auth.currentUser {
                AuthenticatedHomeView(auth: auth, user: user)
            } else {
                AuthEntryView(auth: auth)
            }
        }
        .tint(ProfileTheme.accent)
        .task {
            await auth.restoreSession()
        }
    }
}

// Login and registration navigation
private struct AuthEntryView: View {
    @ObservedObject var auth: AuthManager
    @State private var showingRegistration = false

    var body: some View {
        NavigationStack {
            Group {
                if showingRegistration {
                    RegisterView(auth: auth) {
                        auth.clearError()
                        showingRegistration = false
                    }
                } else {
                    LoginView(auth: auth) {
                        auth.clearError()
                        showingRegistration = true
                    }
                }
            }
            .navigationTitle(
                showingRegistration ? "Create account" : "Log in"
            )
        }
    }
}

// Screen displayed after successful login
private struct AuthenticatedHomeView: View {
    @ObservedObject var auth: AuthManager
    let user: AuthUser

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Signed in",
                            systemImage: "checkmark.shield.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ProfileTheme.accent)

                        Text("Welcome, \(user.name)!")
                            .font(.title2.weight(.bold))

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Current development build") {
                    NavigationLink(
                        "Open Luis's profile preview"
                    ) {
                        ProfileView(
                            store: ProfileSampleData.makeStore()
                        )
                    }

                    Text(
                        "The profile currently uses sample data. " +
                        "Account integration will be added later."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await auth.logout()
                        }
                    } label: {
                        HStack {
                            Label(
                                "Log out",
                                systemImage:
                                    "rectangle.portrait.and.arrow.right"
                            )

                            Spacer()

                            if auth.isWorking {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(auth.isWorking)
                }

                if let error = auth.errorMessage {
                    Section {
                        Label(
                            error,
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.red)
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("Researcher")
        }
    }
}
