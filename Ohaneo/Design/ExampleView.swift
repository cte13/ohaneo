import OhaneoCore
import SwiftUI

/// A Korean example sentence with the studied part underlined in red pen,
/// its English translation, and a listen button.
struct ExampleView: View {
    let example: Example

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(highlighted)
                    .font(.koreanBody)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(example.english)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ListenButton(text: example.korean, size: .small)
        }
    }

    private var highlighted: AttributedString {
        var text = AttributedString(example.korean)
        if let highlight = example.highlight, !highlight.isEmpty, let range = text.range(of: highlight) {
            text[range].foregroundColor = Theme.redPen
            text[range].underlineStyle = Text.LineStyle(pattern: .solid, color: Theme.redPen)
        }
        return text
    }
}

/// Speaker button that reads Korean aloud.
struct ListenButton: View {
    enum Size { case small, regular }

    let text: String
    var size: Size = .regular

    var body: some View {
        Button {
            Speaker.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(size == .small ? .subheadline : .title3)
                .foregroundStyle(Theme.grid)
                .frame(width: 44, height: 44)
                .overlay {
                    if size == .regular {
                        Circle().stroke(Theme.gridFaint, lineWidth: 1).padding(2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Listen")
    }
}
