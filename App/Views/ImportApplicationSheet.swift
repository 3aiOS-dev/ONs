import SwiftUI
import UniformTypeIdentifiers

struct ImportApplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.forgeTheme) private var T

    @State private var showIPAImporter = false
    @State private var showURLImporter = false

    @Binding var importURLText: String
    let isDownloadingURL: Bool
    let onImportURL: () -> Void

    let ipaURL: URL?
    let appName: String
    let bundleID: String
    let preflightState: IPAPreflightState
    let importedURLs: [URL]
    let onIPA: (URL) -> Void
    let onOpenApp: (URL) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    importChoices

                    GlassSection("Your Application") {
                        if importedURLs.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 10) {
                                ForEach(importedURLs, id: \.path) { url in
                                    importedApplicationCard(url: url, isActive: url.path == ipaURL?.path)
                                }
                            }
                        }
                    }

                }
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background { ForgeBackdrop() }
            .sheet(isPresented: $showIPAImporter) {
                ForgeDocumentPicker { urls in
                    showIPAImporter = false
                    guard let url = urls.first else { return }
                    let ext = url.pathExtension.lowercased()
                    guard ext == "ipa" || ext == "zip" else { return }
                    onIPA(url)
                } onCancel: {
                    showIPAImporter = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showURLImporter) {
                URLImportSheet(
                    urlText: $importURLText,
                    isLoading: isDownloadingURL,
                    importAction: onImportURL
                )
            }
            .navigationTitle("Import Application")
            .navigationBarTitleDisplayMode(.inline)
        }
        .floatingGlassBackButton(action: { dismiss() })
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var importChoices: some View {
        HStack(spacing: 10) {
            primaryAction(title: "IPA", icon: "folder") {
                showIPAImporter = true
            }
            primaryAction(title: "URL", icon: "link") {
                showURLImporter = true
            }
        }
        .padding(.horizontal, T.pad)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(T.ink3)
            Text("Import an IPA from Files or URL")
                .font(T.sans(14, .medium))
                .foregroundColor(T.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func importedApplicationCard(url: URL, isActive: Bool) -> some View {
        Button(action: { onOpenApp(url) }) {
            HStack(spacing: 12) {
                Image(systemName: "app.fill")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundColor(T.accent2)
                    .frame(width: 58, height: 58)
                    .glassSurface(.button, cornerRadius: 15)

                VStack(alignment: .leading, spacing: 5) {
                    Text(isActive && !appName.isEmpty ? appName : url.deletingPathExtension().lastPathComponent)
                        .font(T.sans(16, .semibold))
                        .foregroundColor(T.ink)
                        .lineLimit(1)

                    if isActive {
                        switch preflightState {
                        case .ready(let inspection):
                            Text(inspection.bundleIdentifier)
                                .font(T.mono(10))
                                .foregroundColor(T.ink3)
                                .lineLimit(1)
                        case .inspecting:
                            Text("Reading app details…")
                                .font(T.mono(10))
                                .foregroundColor(T.ink3)
                        default:
                            Text(bundleID.isEmpty ? "Tap to edit and sign" : bundleID)
                                .font(T.mono(10))
                                .foregroundColor(T.ink3)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Tap to edit and sign")
                            .font(T.mono(10))
                            .foregroundColor(T.ink3)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)
            }
            .padding(.horizontal, 14)
            .frame(height: 82)
            .glassSurface(.card, cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(T.rule, lineWidth: AppStroke.hairline)
            }
        }
        .buttonStyle(GlassTactileButtonStyle())
        .padding(.horizontal, T.pad)
    }

    private func primaryAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(LocalizedStringKey(title))
                    .font(T.sans(15, .semibold))
            }
            .foregroundColor(T.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .glassSurface(.button, cornerRadius: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(T.rule, lineWidth: AppStroke.hairline)
            }
        }
        .buttonStyle(GlassTactileButtonStyle())
    }

    private func secondaryAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(LocalizedStringKey(title))
                    .font(T.sans(14, .medium))
            }
            .foregroundColor(T.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .glassSurface(.button, cornerRadius: 14)
        }
        .buttonStyle(GlassTactileButtonStyle())
    }
}

private extension View {
    @ViewBuilder
    func importApplicationSectionStyle<T: View>(@ViewBuilder content: () -> T) -> some View {
        content()
    }
}
