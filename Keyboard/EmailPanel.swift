//
//  EmailPanel.swift
//  Keyboard Pro
//
//  The list of remembered email addresses, opened by holding the key left of
//  the space bar. Most used first. Tap to type one, swipe left to forget one.
//

import UIKit

final class EmailPanel: UIView, UITableViewDataSource, UITableViewDelegate {
    var onPick: ((String) -> Void)?
    var onClose: (() -> Void)?

    private let table = UITableView(frame: .zero, style: .plain)
    private let empty = UILabel()
    private var entries: [EmailMemory.Entry] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Saved emails"
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .label

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        done.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [title, UIView(), done])
        header.axis = .horizontal
        header.alignment = .center
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 48               // tall enough that the text is never clipped
        table.separatorInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        table.register(UITableViewCell.self, forCellReuseIdentifier: "email")

        empty.text = "No emails saved yet.\nType an email address and press space."
        empty.numberOfLines = 0
        empty.textAlignment = .center
        empty.font = .systemFont(ofSize: 14)
        empty.textColor = .secondaryLabel
        table.backgroundView = empty

        let column = UIStackView(arrangedSubviews: [header, table])
        column.axis = .vertical
        column.spacing = 2
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            header.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Loads the latest list and scrolls to the top (the most used).
    func reload() {
        entries = EmailMemory.ranked()
        empty.isHidden = !entries.isEmpty
        table.reloadData()
        if !entries.isEmpty { table.setContentOffset(.zero, animated: false) }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "email", for: indexPath)
        let entry = entries[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = entry.email
        content.textProperties.font = .systemFont(ofSize: 16)
        content.textProperties.color = .label
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        onPick?(entries[indexPath.row].email)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let email = entries[indexPath.row].email
        let forget = UIContextualAction(style: .destructive, title: "Forget") { [weak self] _, _, done in
            EmailMemory.remove(email)
            self?.reload()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [forget])
    }
}
