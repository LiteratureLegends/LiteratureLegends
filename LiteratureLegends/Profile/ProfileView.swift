import SwiftUI

struct ProfileView: View {
    @ObservedObject var store: ProfileStore

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Text(store.profile.initials)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 64, height: 64)
                        .background(.tint.opacity(0.08), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.profile.name).font(.title2.weight(.semibold))
                        Text("@\(store.profile.userName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 12)
            }

            Section("Account information") {
                LabeledContent("Name", value: store.profile.name)
                LabeledContent("Username", value: store.profile.userName)
                LabeledContent("Email", value: store.profile.email)
                    .textSelection(.enabled)
                LabeledContent("Member since", value: store.profile.createdAt.formatted(.dateTime.month(.wide).year()))
            }

            Section {
                NavigationLink {
                    EditProfileView(store: store)
                } label: {
                    Label("Edit profile", systemImage: "square.and.pencil")
                        .foregroundStyle(.tint)
                }
            } footer: {
                Text("Sample profile. Changes reset when the app closes.")
            }
        }
        .navigationTitle("Profile")
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView(store: ProfileSampleData.makeStore())
        }
        .tint(ProfileTheme.accent)
        .previewDisplayName("Profile")

        NavigationStack {
            ProfileView(store: ProfileSampleData.makeStore())
        }
        .tint(ProfileTheme.accent)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .accessibility3)
        .previewDisplayName("Dark, large text")
    }
}
