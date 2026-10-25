import SwiftUI

/// Text written one character per square, the way it's written on 원고지.
/// Spaces take a square of their own. Long text wraps into more rows, with the
/// thin gap between rows that manuscript paper has.
struct ManuscriptGrid: View {
    let text: String
    /// Largest square size; squares shrink to fit, then wrap.
    var cellSize: CGFloat = 76
    var minimumCellSize: CGFloat = 46

    private var characters: [Character] { Array(text) }

    var body: some View {
        ManuscriptLayout(preferred: cellSize, minimum: minimumCellSize, rowGap: max(4, cellSize * 0.08)) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                Cell(character: character)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isStaticText)
    }

    private struct Cell: View {
        let character: Character

        var body: some View {
            GeometryReader { proxy in
                let side = proxy.size.width
                ZStack {
                    Rectangle().fill(Theme.paperRaised.opacity(0.55))
                    Text(String(character))
                        .font(.custom("GowunBatang-Bold", fixedSize: side * 0.62))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .overlay(Rectangle().stroke(Theme.grid, lineWidth: 1))
            }
        }
    }
}

/// Square cells in rows. One row at the preferred size if it fits, otherwise
/// shrink down to the minimum, otherwise wrap.
private struct ManuscriptLayout: Layout {
    let preferred: CGFloat
    let minimum: CGFloat
    let rowGap: CGFloat

    private func metrics(count: Int, width: CGFloat?) -> (cell: CGFloat, columns: Int, rows: Int) {
        guard count > 0 else { return (preferred, 0, 0) }
        let available = width ?? preferred * CGFloat(count)
        if CGFloat(count) * preferred <= available { return (preferred, count, 1) }
        if CGFloat(count) * minimum <= available { return (floor(available / CGFloat(count)), count, 1) }
        let columns = max(1, Int(available / minimum))
        let rows = Int(ceil(Double(count) / Double(columns)))
        return (floor(available / CGFloat(columns)), columns, rows)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let m = metrics(count: subviews.count, width: proposal.width)
        let width = m.cell * CGFloat(m.columns)
        let height = m.cell * CGFloat(m.rows) + rowGap * CGFloat(max(0, m.rows - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let m = metrics(count: subviews.count, width: bounds.width)
        guard m.columns > 0 else { return }
        for (index, subview) in subviews.enumerated() {
            let row = index / m.columns
            let column = index % m.columns
            let origin = CGPoint(
                x: bounds.minX + CGFloat(column) * m.cell,
                y: bounds.minY + CGFloat(row) * (m.cell + rowGap)
            )
            subview.place(at: origin, proposal: ProposedViewSize(width: m.cell, height: m.cell))
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        ManuscriptGrid(text: "괜찮아요")
        ManuscriptGrid(text: "-(으)ㄴ/는데")
        ManuscriptGrid(text: "가는 말이 고와야 오는 말이 곱다")
        ManuscriptGrid(text: "학교", cellSize: 36, minimumCellSize: 30)
    }
    .padding(Theme.margin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .paperBackground()
}
