import SwiftUI

#if os(macOS)
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {

            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            Text("EasySnap+")
                .font(.title)
                .fontWeight(.bold)

            Text("v1.1.0")
                .foregroundColor(.secondary)
                .font(.callout)

            Text("A simple video frame and PDF page extractor for macOS.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Compatible formats: PDF, MP4, MOV, MKV, AVI, WMV, FLV, WebM, and more.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            VStack(spacing: 6) {
                Text("Developer")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("Nyeongwoo Kwon")
                        .foregroundColor(.secondary)
                    Spacer()
                    Link("GitHub", destination: URL(string: "https://github.com/Nyeongwoo")!)
                        .foregroundColor(.accentColor)
                        .focusable(false)
                }
            }

            Divider()

            VStack(spacing: 6) {
                Text("License")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FFmpeg")
                            .foregroundColor(.secondary)
                        Text("Licensed under GPL 2.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Link("View License", destination: URL(string: "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html")!)
                        .foregroundColor(.accentColor)
                        .focusable(false)
                }
            }

            Divider()

            VStack(spacing: 6) {
                Text("Support")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("Found a bug or have a suggestion?")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Spacer()
                    Link("GitHub Issues", destination: URL(string: "https://github.com/Nyeongwoo/EasySnap/issues")!)
                        .foregroundColor(.accentColor)
                        .focusable(false)
                }
            }

            Divider()

            Text("© 2026 Nyeongwoo Kwon. Released under GPL 2.0.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 320)
    }
}

#Preview {
    AboutView()
}
#endif
