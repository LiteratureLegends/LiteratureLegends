import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    let user: AuthUser

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Text(InitialsBadge(name: user.displayName).initials)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 64, height: 64)
                        .background(.tint.opacity(0.08), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(user.displayName).font(.title2.weight(.semibold))
                        if !user.email.isEmpty && user.email != user.displayName {
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 12)
            }

            Section("Account information") {
                if !user.name.isEmpty {
                    LabeledContent("Name", value: user.name)
                }
                if !user.email.isEmpty {
                    LabeledContent("Email", value: user.email)
                        .textSelection(.enabled)
                }
                if let username = user.username, username != user.email {
                    LabeledContent("Username", value: username)
                }
                if let createdAt = user.createdAt {
                    LabeledContent("Member since", value: createdAt.formatted(.dateTime.month(.wide).year()))
                }
            }

            Section {
                NavigationLink {
                    EditProfileView(user: user)
                } label: {
                    Label("Edit profile", systemImage: "square.and.pencil")
                        .foregroundStyle(.tint)
                }
            }
            Section {
                Button(role: .destructive) {
                    Task { await auth.logout() }
                } label: {
                    HStack {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                        if auth.isWorking { ProgressView() }
                    }
                }
                .disabled(auth.isWorking)

                if let error = auth.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }
}

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView(user: ProfileSampleData.user)
        }
        .environmentObject(AuthManager())
        .tint(ProfileTheme.accent)
        .previewDisplayName("Profile")

        NavigationStack {
            ProfileView(user: ProfileSampleData.user)
        }
        .environmentObject(AuthManager())
        .tint(ProfileTheme.accent)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .accessibility3)
        .previewDisplayName("Dark, large text")
    }
}
#endif
