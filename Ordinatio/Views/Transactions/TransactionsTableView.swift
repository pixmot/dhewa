import OrdinatioCore
import SwiftUI
import UIKit

struct TransactionSectionHeaderModel: Hashable, Sendable {
    let title: String
    let totalText: String?
}

struct TransactionsTableView: UIViewRepresentable {
    let sections: [TransactionSection]
    let headerModels: [TransactionSectionHeaderModel]
    let summaryHeader: AnyView
    let onSelectRow: (TransactionListRow) -> Void
    let onEdit: (TransactionListRow) -> Void
    let onDelete: (TransactionListRow, CGRect?) -> Void
    let onSwipeHaptic: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sections: sections,
            headerModels: headerModels,
            summaryHeader: summaryHeader,
            onSelectRow: onSelectRow,
            onEdit: onEdit,
            onDelete: onDelete,
            onSwipeHaptic: onSwipeHaptic
        )
    }

    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = UIColor(OrdinatioColor.background)
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 28
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Coordinator.cellIdentifier)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: Coordinator.headerIdentifier)
        context.coordinator.tableView = tableView
        context.coordinator.update(
            sections: sections,
            headerModels: headerModels,
            summaryHeader: summaryHeader,
            onSelectRow: onSelectRow,
            onEdit: onEdit,
            onDelete: onDelete,
            onSwipeHaptic: onSwipeHaptic
        )
        return tableView
    }

    func updateUIView(_ tableView: UITableView, context: Context) {
        context.coordinator.update(
            sections: sections,
            headerModels: headerModels,
            summaryHeader: summaryHeader,
            onSelectRow: onSelectRow,
            onEdit: onEdit,
            onDelete: onDelete,
            onSwipeHaptic: onSwipeHaptic
        )
    }

    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        static let cellIdentifier = "TransactionCell"
        static let headerIdentifier = "TransactionSectionHeader"

        weak var tableView: UITableView?

        private var sections: [TransactionSection]
        private var headerModels: [TransactionSectionHeaderModel]
        private var summaryHeader: AnyView
        private var onSelectRow: (TransactionListRow) -> Void
        private var onEdit: (TransactionListRow) -> Void
        private var onDelete: (TransactionListRow, CGRect?) -> Void
        private var onSwipeHaptic: () -> Void
        private var headerHost: UIHostingController<AnyView>?

        init(
            sections: [TransactionSection],
            headerModels: [TransactionSectionHeaderModel],
            summaryHeader: AnyView,
            onSelectRow: @escaping (TransactionListRow) -> Void,
            onEdit: @escaping (TransactionListRow) -> Void,
            onDelete: @escaping (TransactionListRow, CGRect?) -> Void,
            onSwipeHaptic: @escaping () -> Void
        ) {
            self.sections = sections
            self.headerModels = headerModels
            self.summaryHeader = summaryHeader
            self.onSelectRow = onSelectRow
            self.onEdit = onEdit
            self.onDelete = onDelete
            self.onSwipeHaptic = onSwipeHaptic
        }

        func update(
            sections: [TransactionSection],
            headerModels: [TransactionSectionHeaderModel],
            summaryHeader: AnyView,
            onSelectRow: @escaping (TransactionListRow) -> Void,
            onEdit: @escaping (TransactionListRow) -> Void,
            onDelete: @escaping (TransactionListRow, CGRect?) -> Void,
            onSwipeHaptic: @escaping () -> Void
        ) {
            self.sections = sections
            self.headerModels = headerModels
            self.summaryHeader = summaryHeader
            self.onSelectRow = onSelectRow
            self.onEdit = onEdit
            self.onDelete = onDelete
            self.onSwipeHaptic = onSwipeHaptic
            configureHeader()
            tableView?.reloadData()
        }

        func numberOfSections(in tableView: UITableView) -> Int {
            sections.count
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            sections[section].rows.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let row = sections[indexPath.section].rows[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
            cell.selectionStyle = .none
            cell.backgroundColor = UIColor(OrdinatioColor.background)
            cell.contentConfiguration = UIHostingConfiguration {
                TransactionRowView(row: row)
                    .background(OrdinatioColor.background)
                    .contextMenu {
                        Button {
                            self.onEdit(row)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            self.onDelete(row, nil)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .accessibilityIdentifier("TransactionRow.\(row.id)")
            }
            .margins(.all, 0)
            return cell
        }

        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            let row = sections[indexPath.section].rows[indexPath.row]
            onSelectRow(row)
        }

        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            guard headerModels.indices.contains(section) else { return nil }
            let model = headerModels[section]
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.headerIdentifier)
            header?.contentConfiguration = UIHostingConfiguration {
                TransactionSectionHeaderView(title: model.title, totalText: model.totalText)
            }
            .margins(.all, 0)
            header?.contentView.backgroundColor = UIColor(OrdinatioColor.background)
            header?.backgroundView = UIView()
            header?.backgroundView?.backgroundColor = UIColor(OrdinatioColor.background)
            return header
        }

        func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            let row = sections[indexPath.section].rows[indexPath.row]

            let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, completion in
                self?.onEdit(row)
                completion(true)
            }
            edit.image = UIImage(
                systemName: "pencil",
                withConfiguration: UIImage.SymbolConfiguration(weight: .semibold)
            )
            edit.backgroundColor = UIColor(OrdinatioColor.actionBlue)

            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                if let tableView = self?.tableView {
                    let rowRect = tableView.rectForRow(at: indexPath)
                    let originWidth: CGFloat = 72
                    let originHeight = min(44, rowRect.height)
                    let originRect = CGRect(
                        x: rowRect.maxX - originWidth - 8,
                        y: rowRect.midY - originHeight / 2,
                        width: originWidth,
                        height: originHeight
                    )
                    let windowRect = tableView.convert(originRect, to: nil)
                    self?.onDelete(row, windowRect)
                } else {
                    self?.onDelete(row, nil)
                }
                completion(true)
            }
            delete.image = UIImage(
                systemName: "trash",
                withConfiguration: UIImage.SymbolConfiguration(weight: .semibold)
            )
            delete.backgroundColor = UIColor(OrdinatioColor.expense)

            let configuration = UISwipeActionsConfiguration(actions: [delete, edit])
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }

        func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
            onSwipeHaptic()
        }

        private func configureHeader() {
            guard let tableView else { return }
            tableView.layoutIfNeeded()
            let width = tableView.bounds.width
            guard width > 0 else { return }

            if headerHost == nil {
                headerHost = UIHostingController(rootView: summaryHeader)
                headerHost?.view.backgroundColor = .clear
            } else {
                headerHost?.rootView = summaryHeader
            }

            guard let host = headerHost else { return }
            let size = host.view.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            host.view.frame = CGRect(origin: .zero, size: size)
            tableView.tableHeaderView = host.view
        }
    }
}

private struct TransactionSectionHeaderView: View {
    let title: String
    let totalText: String?

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .textCase(.uppercase)

                Spacer()

                if let totalText {
                    Text(totalText)
                        .layoutPriority(1)
                }
            }
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .foregroundStyle(OrdinatioColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            HeaderLine()
                .stroke(OrdinatioColor.separator, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .background(OrdinatioColor.background)
    }
}

private struct HeaderLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}
