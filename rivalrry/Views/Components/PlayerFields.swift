import SwiftUI
import PhotosUI
import UIKit

/// Avatar with photo picker, name field and color picker. Used by S0, S4 and S9.
struct PlayerFields: View {
    @Binding var name: String
    @Binding var colorHex: String
    @Binding var photo: Data?
    let nameIssue: FriendForm.NameIssue?
    var focusesName = false
    var onSubmit: () -> Void = {}

    @State private var photoItem: PhotosPickerItem?
    @State private var showsNameIssue = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: Spacing.l) {
            avatar
            nameField
            colorPicker
        }
        .onAppear { if focusesName { nameFocused = true } }
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    private var avatar: some View {
        VStack(spacing: Spacing.s) {
            AvatarView(name: name.isEmpty ? "?" : name, colorHex: colorHex, photo: photo, size: 96)
            HStack(spacing: Spacing.m) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text(photo == nil ? "Add Photo" : "Change Photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rvTextPrimary)
                        .frame(minHeight: 44)
                }
                if photo != nil {
                    Button("Remove Photo") {
                        photo = nil
                        photoItem = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rvTextSecondary)
                    .frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Name")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
            TextField("Name", text: $name)
                .font(.body)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .padding(Spacing.m)
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .onChange(of: name) { _, newName in
                    showsNameIssue = true
                    // Hard limit while typing (plan.md: 1–20 characters).
                    if newName.count > FriendForm.nameLimit { name = String(newName.prefix(FriendForm.nameLimit)) }
                }
                .onSubmit(onSubmit)
            if showsNameIssue, let nameIssue, nameIssue != .empty {
                Label(nameIssue.message, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
            // Evenly spread, so 8 colors always fit the width.
            HStack(spacing: 0) {
                ForEach(FriendForm.colors, id: \.self) { hex in
                    let isSelected = hex == colorHex
                    Button {
                        withAnimation(.spring(duration: 0.3)) { colorHex = hex }
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 32, height: 32)
                            .padding(3)
                            .overlay {
                                if isSelected { Circle().strokeBorder(Color.rvTextPrimary, lineWidth: 2) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(hex)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: colorHex)
        }
    }

    /// Loads the picked image and shrinks it, so photos don't bloat the database.
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photo = image.avatarJPEG()
    }
}

private extension UIImage {
    /// Thumbnail, max. 512 pt on the long side, as JPEG.
    func avatarJPEG(maxSide: CGFloat = 512) -> Data? {
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
