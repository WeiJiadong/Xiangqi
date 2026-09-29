import SwiftUI

struct MoveListView: View {
    let notations: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(rows), id: \.offset) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(row.offset + 1).")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 32, alignment: .leading)
                            Text(row.red)
                                .font(.system(.body))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(row.black)
                                .font(.system(.body))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .id(row.offset)
                    }
                }
                .padding(.horizontal, 8)
            }
            .onChange(of: notations.count) { _, _ in
                let idx = (notations.count - 1) / 2
                withAnimation { proxy.scrollTo(idx, anchor: .bottom) }
            }
        }
    }

    private var rows: [(offset: Int, red: String, black: String)] {
        var r: [(offset: Int, red: String, black: String)] = []
        var i = 0
        while i < notations.count {
            r.append((r.count, notations[i], i + 1 < notations.count ? notations[i + 1] : ""))
            i += 2
        }
        return r
    }
}
