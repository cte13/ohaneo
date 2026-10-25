import OhaneoCore
import SwiftData
import SwiftUI

struct HistoryView: View {
    private static let shown = #Predicate<StudyItem> { item in
        item.statusRaw != "upcoming"
    }

    @Query(filter: shown, sort: \StudyItem.createdAt, order: .reverse)
    private var items: [StudyItem]

    @State private var search = ""
    @State private var kind: ItemKind?
    @State private var status: ItemStatus?

    private var filtered: [StudyItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            (kind == nil || item.kind == kind)
                && (status == nil || item.status == status)
                && (query.isEmpty
                    || item.korean.localizedStandardContains(query)
                    || item.meaning.localizedStandardContains(query))
        }
    }

    private var days: [(day: Date, items: [StudyItem])] {
        let groups = Dictionary(grouping: filtered) { $0.scheduledFor ?? .distantPast }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "square.grid.3x1.below.line.grid.1x2",
                        description: Text("Words, phrases and grammar from Today appear here.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    list
                }
            }
            .paperBackground()
            .navigationTitle("History")
            .searchable(text: $search, prompt: "Search Korean or English")
            .toolbar { filterMenu }
            .navigationDestination(for: StudyItem.self) { ItemDetailView(item: $0) }
        }
    }

    private var list: some View {
        List {
            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.items) { item in
                        NavigationLink(value: item) { HistoryRow(item: item) }
                            .listRowBackground(Theme.paper)
                    }
                } header: {
                    Text(group.day, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.grid)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var filterMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Type", selection: $kind) {
                    Text("All types").tag(ItemKind?.none)
                    Text("Words").tag(ItemKind?.some(.word))
                    Text("Phrases").tag(ItemKind?.some(.phrase))
                    Text("Grammar").tag(ItemKind?.some(.grammar))
                }
                Picker("Status", selection: $status) {
                    Text("Any status").tag(ItemStatus?.none)
                    Text("Learning").tag(ItemStatus?.some(.learning))
                    Text("Known").tag(ItemStatus?.some(.known))
                    Text("Skipped").tag(ItemStatus?.some(.skipped))
                }
            } label: {
                Label("Filter", systemImage: kind == nil && status == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }
}

private struct HistoryRow: View {
    let item: StudyItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.korean)
                    .font(.koreanRow)
                    .foregroundStyle(Theme.ink)
                Text(item.meaning)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
            }
            Spacer()
            StatusLabel(status: item.status)
        }
        .padding(.vertical, 4)
    }
}

struct StatusLabel: View {
    let status: ItemStatus

    var body: some View {
        switch status {
        case .learning:
            Text("Learning").font(.footnote.weight(.medium)).foregroundStyle(Theme.grid)
        case .known:
            Text("Known").font(.footnote).foregroundStyle(Theme.inkSecondary)
        case .skipped:
            Text("Skipped").font(.footnote).foregroundStyle(Theme.inkSecondary.opacity(0.7))
        case .new:
            Text("No answer").font(.footnote).foregroundStyle(Theme.inkSecondary)
        case .upcoming:
            EmptyView()
        }
    }
}

struct ItemDetailView: View {
    let item: StudyItem
    @Environment(StudyService.self) private var service

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                CardFront(item: item)
                CardDetails(item: item)
                GridRule()
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading("Your answer")
                    Picker("Your answer", selection: Binding(
                        get: { item.status },
                        set: { service.mark(item, as: $0) }
                    )) {
                        Text("Learning").tag(ItemStatus.learning)
                        Text("I know this").tag(ItemStatus.known)
                    }
                    .pickerStyle(.segmented)
                    if item.status == .skipped || item.status == .new {
                        Text(item.status == .skipped ? "You skipped this one." : "You haven't answered yet.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}
