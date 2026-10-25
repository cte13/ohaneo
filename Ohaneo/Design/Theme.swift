import SwiftUI

/// 원고지 (Korean manuscript paper): cool paper, green grid lines, navy pen ink,
/// and a teacher's red pen used only to mark the word or pattern being studied.
enum Theme {
    static let paper = Color("Paper")
    static let paperRaised = Color("PaperRaised")
    static let grid = Color("Grid")
    static let gridFaint = Color("GridFaint")
    static let ink = Color("Ink")
    static let inkSecondary = Color("InkSecondary")
    static let redPen = Color("RedPen")

    /// Horizontal page margin.
    static let margin: CGFloat = 20
}

/// Korean text is set in Gowun Batang; English and controls use the system font.
extension Font {
    static func batang(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(bold ? "GowunBatang-Bold" : "GowunBatang-Regular", size: size, relativeTo: style)
    }

    /// Korean example sentences.
    static let koreanBody = batang(19, relativeTo: .body)
    /// Korean in lists and small headings.
    static let koreanRow = batang(21, bold: true, relativeTo: .title3)
    /// Section headings ("How to form it"), sentence case.
    static let sectionHeading = Font.system(.subheadline, weight: .semibold)
}

/// A thin green rule like the line between rows on manuscript paper.
struct GridRule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.gridFaint)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct SectionHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.sectionHeading)
            .foregroundStyle(Theme.grid)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// The paper background used by every screen.
    func paperBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}
