import UIKit
import SeatLayer

enum DemoPalette {
    static let red = UIColor(red: 0.90, green: 0.27, blue: 0.35, alpha: 1)
    static let ink = UIColor(red: 0.23, green: 0.18, blue: 0.30, alpha: 1)
    static let background = UIColor(red: 0.97, green: 0.96, blue: 0.97, alpha: 1)
    static let muted = UIColor(red: 0.43, green: 0.40, blue: 0.46, alpha: 1)
    static let line = UIColor(red: 0.89, green: 0.87, blue: 0.90, alpha: 1)
    static let success = UIColor(red: 0.08, green: 0.55, blue: 0.36, alpha: 1)
    static let map = UIColor.white
}

private enum DemoFormat {
    private static let inputDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM h:mm a")
        return formatter
    }()

    static func date(for event: DesiPassEvent) -> String {
        let time = String(event.eventStartTime.prefix(8))
        guard let date = inputDate.date(from: "\(event.eventStartDate) \(time)") else {
            return "\(event.eventStartDate) · \(event.eventStartTime)"
        }
        return displayDate.string(from: date)
    }

    static func money(_ value: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "EUR"
        formatter.locale = .current
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency ?? "EUR") \(value)"
    }

    static func startingPrice(for event: DesiPassEvent) -> String {
        guard let price = event.minimumPrice else { return "View tickets" }
        return "From \(money(price, currency: event.currency))"
    }
}

private func makeLabel(
    textStyle: UIFont.TextStyle,
    weight: UIFont.Weight = .regular,
    color: UIColor = DemoPalette.ink,
    lines: Int = 1
) -> UILabel {
    let label = UILabel()
    label.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: textStyle).pointSize, weight: weight)
    label.adjustsFontForContentSizeCategory = true
    label.textColor = color
    label.numberOfLines = lines
    label.textAlignment = .natural
    return label
}

private final class PrimaryButton: UIButton {
    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.45 }
    }
}

private func makePrimaryButton(title: String) -> UIButton {
    let button = PrimaryButton(type: .system)
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = DemoPalette.red
    button.layer.cornerRadius = 14
    return button
}

private final class RemoteImageView: UIImageView {
    private var request: URLSessionDataTask?
    private var representedURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        contentMode = .center
        backgroundColor = UIColor(red: 1, green: 0.91, blue: 0.92, alpha: 1)
        tintColor = DemoPalette.red
        image = UIImage(systemName: "ticket.fill")
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { nil }

    func load(_ rawURL: String?) {
        request?.cancel()
        request = nil
        representedURL = nil
        contentMode = .center
        image = UIImage(systemName: "ticket.fill")

        guard let rawURL, let url = URL(string: rawURL) else { return }
        representedURL = url
        request = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            guard (200..<300).contains(status), let data, let downloaded = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard self?.representedURL == url else { return }
                self?.contentMode = .scaleAspectFill
                self?.image = downloaded
            }
        }
        request?.resume()
    }

    deinit { request?.cancel() }
}

// MARK: - Event list

final class DesiPassDemoViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private let stateView = UIView()
    private let stateStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let stateLabel = makeLabel(textStyle: .body, color: DemoPalette.muted, lines: 3)
    private let retryButton = UIButton(type: .system)
    private var events: [DesiPassEvent] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Events"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = DemoPalette.background
        buildUI()
        setLoading(true)
        Task { await loadEvents() }
    }

    private func buildUI() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = DemoPalette.background
        tableView.separatorStyle = .none
        tableView.rowHeight = 154
        tableView.estimatedRowHeight = 154
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 20, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(EventCardCell.self, forCellReuseIdentifier: EventCardCell.reuseIdentifier)
        tableView.accessibilityIdentifier = "desipass-event-list"
        view.addSubview(tableView)

        let header = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 100))
        header.backgroundColor = DemoPalette.background
        let eyebrow = makeLabel(textStyle: .caption1, weight: .bold, color: DemoPalette.red)
        eyebrow.text = "DESIPASS DEV"
        let intro = makeLabel(textStyle: .title2, weight: .bold, lines: 2)
        intro.text = "Choose an event to validate SeatLayer."
        let headerStack = UIStackView(arrangedSubviews: [eyebrow, intro])
        headerStack.axis = .vertical
        headerStack.spacing = 7
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: header.topAnchor, constant: 14),
            headerStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
        ])
        tableView.tableHeaderView = header

        refreshControl.tintColor = DemoPalette.red
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        stateView.backgroundColor = DemoPalette.background
        stateStack.axis = .vertical
        stateStack.alignment = .center
        stateStack.spacing = 12
        stateStack.translatesAutoresizingMaskIntoConstraints = false
        stateView.addSubview(stateStack)
        stateStack.addArrangedSubview(spinner)
        stateStack.addArrangedSubview(stateLabel)
        stateStack.addArrangedSubview(retryButton)
        stateLabel.textAlignment = .center
        retryButton.setTitle("Try again", for: .normal)
        retryButton.setTitleColor(DemoPalette.red, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        NSLayoutConstraint.activate([
            stateStack.centerXAnchor.constraint(equalTo: stateView.centerXAnchor),
            stateStack.centerYAnchor.constraint(equalTo: stateView.centerYAnchor, constant: -30),
            stateStack.leadingAnchor.constraint(greaterThanOrEqualTo: stateView.leadingAnchor, constant: 28),
            stateStack.trailingAnchor.constraint(lessThanOrEqualTo: stateView.trailingAnchor, constant: -28),
        ])

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func refresh() {
        Task { await loadEvents() }
    }

    @objc private func retry() {
        setLoading(true)
        Task { await loadEvents() }
    }

    private func setLoading(_ loading: Bool) {
        tableView.backgroundView = stateView
        stateLabel.text = loading ? "Loading SeatLayer events…" : nil
        retryButton.isHidden = loading
        loading ? spinner.startAnimating() : spinner.stopAnimating()
    }

    private func loadEvents() async {
        do {
            let loaded = try await DesiPassClient.shared.fetchDemoEvents()
            events = loaded
            tableView.reloadData()
            if loaded.isEmpty {
                tableView.backgroundView = stateView
                spinner.stopAnimating()
                retryButton.isHidden = false
                stateLabel.text = "No upcoming SeatLayer events were returned by DesiPass."
            } else {
                tableView.backgroundView = nil
            }
        } catch {
            events = []
            tableView.reloadData()
            tableView.backgroundView = stateView
            spinner.stopAnimating()
            retryButton.isHidden = false
            stateLabel.text = error.localizedDescription
        }
        refreshControl.endRefreshing()
    }
}

extension DesiPassDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        events.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: EventCardCell.reuseIdentifier,
            for: indexPath
        ) as? EventCardCell else { return UITableViewCell() }
        cell.configure(with: events[indexPath.row])
        cell.accessibilityIdentifier = "event-card-\(indexPath.row)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(
            EventDetailViewController(event: events[indexPath.row]),
            animated: true
        )
    }
}

private final class EventCardCell: UITableViewCell {
    static let reuseIdentifier = "EventCardCell"

    private let card = UIView()
    private let eventImageView = RemoteImageView(frame: .zero)
    private let dateLabel = makeLabel(textStyle: .caption1, weight: .bold, color: DemoPalette.red)
    private let titleLabel = makeLabel(textStyle: .headline, weight: .bold, lines: 2)
    private let locationLabel = makeLabel(textStyle: .subheadline, color: DemoPalette.muted, lines: 2)
    private let priceLabel = makeLabel(textStyle: .subheadline, weight: .bold)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        buildUI()
    }

    required init?(coder: NSCoder) { nil }

    func configure(with event: DesiPassEvent) {
        eventImageView.load(event.eventImageUrl)
        dateLabel.text = DemoFormat.date(for: event).uppercased()
        titleLabel.text = event.title
        locationLabel.text = event.location
        priceLabel.text = DemoFormat.startingPrice(for: event)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = [event.title, DemoFormat.date(for: event), event.location, priceLabel.text]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func buildUI() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .white
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.07
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.addSubview(card)

        eventImageView.translatesAutoresizingMaskIntoConstraints = false
        eventImageView.layer.cornerRadius = 14
        card.addSubview(eventImageView)

        let copy = UIStackView(arrangedSubviews: [dateLabel, titleLabel, locationLabel, priceLabel])
        copy.axis = .vertical
        copy.alignment = .fill
        copy.spacing = 5
        copy.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(copy)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            eventImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            eventImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            eventImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            eventImageView.widthAnchor.constraint(equalToConstant: 116),

            copy.leadingAnchor.constraint(equalTo: eventImageView.trailingAnchor, constant: 14),
            copy.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            copy.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            copy.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 12),
            copy.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -12),
        ])
    }
}

// MARK: - Event details

private final class EventDetailViewController: UIViewController {
    private var event: DesiPassEvent
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let hero = RemoteImageView(frame: .zero)
    private let dateLabel = makeLabel(textStyle: .subheadline, weight: .bold, color: DemoPalette.red)
    private let titleLabel = makeLabel(textStyle: .largeTitle, weight: .bold, lines: 4)
    private let whenLabel = makeLabel(textStyle: .body, weight: .semibold, lines: 2)
    private let whereLabel = makeLabel(textStyle: .body, weight: .semibold, lines: 3)
    private let addressLabel = makeLabel(textStyle: .subheadline, color: DemoPalette.muted, lines: 3)
    private let priceLabel = makeLabel(textStyle: .subheadline, weight: .bold, lines: 2)
    private let bookButton = makePrimaryButton(title: "BOOK NOW")

    init(event: DesiPassEvent) {
        self.event = event
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Event details"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = DemoPalette.background
        buildUI()
        render()
        Task { await refreshDetail() }
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = DemoPalette.background
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 14
        content.isLayoutMarginsRelativeArrangement = true
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 30, trailing: 20)
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.layer.cornerRadius = 20
        content.addArrangedSubview(hero)
        hero.heightAnchor.constraint(equalToConstant: 225).isActive = true

        content.addArrangedSubview(dateLabel)
        content.addArrangedSubview(titleLabel)

        let infoCard = UIView()
        infoCard.backgroundColor = .white
        infoCard.layer.cornerRadius = 18
        let info = UIStackView(arrangedSubviews: [whenLabel, whereLabel, addressLabel])
        info.axis = .vertical
        info.spacing = 10
        info.translatesAutoresizingMaskIntoConstraints = false
        infoCard.addSubview(info)
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 18),
            info.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 18),
            info.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -18),
            info.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -18),
        ])
        content.addArrangedSubview(infoCard)

        let bottomBar = UIView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = .white
        view.addSubview(bottomBar)

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = DemoPalette.line
        bottomBar.addSubview(divider)

        bookButton.translatesAutoresizingMaskIntoConstraints = false
        bookButton.accessibilityIdentifier = "book-now-button"
        bookButton.addTarget(self, action: #selector(bookNow), for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [priceLabel, bookButton])
        actions.axis = .horizontal
        actions.alignment = .center
        actions.spacing = 12
        actions.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(actions)
        bookButton.widthAnchor.constraint(equalToConstant: 158).isActive = true
        bookButton.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.topAnchor.constraint(equalTo: actions.topAnchor, constant: -12),

            divider.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            divider.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            actions.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            actions.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
            actions.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
        ])
    }

    private func render() {
        hero.load(event.eventImageUrl)
        dateLabel.text = DemoFormat.date(for: event).uppercased()
        titleLabel.text = event.title
        whenLabel.text = "When  ·  \(DemoFormat.date(for: event))"
        whereLabel.text = "Where  ·  \(event.location)"
        addressLabel.text = event.venueDetail?.venueAddress
        addressLabel.isHidden = (event.venueDetail?.venueAddress?.isEmpty ?? true)
        priceLabel.text = DemoFormat.startingPrice(for: event)
        view.accessibilityLabel = "\(event.title), \(DemoFormat.date(for: event)), \(event.location)"
    }

    private func refreshDetail() async {
        do {
            event = try await DesiPassClient.shared.fetchEventDetail(eventId: event.id)
            render()
        } catch {
            // The list payload still renders a useful details page. A failure is
            // surfaced if the buyer actually asks to open the map.
        }
    }

    @objc private func bookNow() {
        bookButton.isEnabled = false
        bookButton.setTitle("LOADING…", for: .normal)
        Task {
            do {
                let detail: DesiPassEvent
                if event.seatEventKey?.isEmpty == false {
                    detail = event
                } else {
                    detail = try await DesiPassClient.shared.fetchEventDetail(eventId: event.id)
                    event = detail
                    render()
                }
                navigationController?.pushViewController(
                    SeatPickerViewController(event: detail),
                    animated: true
                )
            } catch {
                showAlert(title: "Unable to open seats", message: error.localizedDescription)
            }
            bookButton.isEnabled = true
            bookButton.setTitle("BOOK NOW", for: .normal)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Native picker

@MainActor
private final class SeatPickerViewController: UIViewController {
    private let event: DesiPassEvent
    private var pickerHost: SeatLayerPickerViewController?
    private var checkoutInvocationCount = 0
    private let activity = UIActivityIndicatorView(style: .large)
    private let loadingLabel = makeLabel(
        textStyle: .body,
        weight: .semibold,
        color: DemoPalette.muted,
        lines: 2
    )

    init(event: DesiPassEvent) {
        self.event = event
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override var childForStatusBarStyle: UIViewController? { pickerHost }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose seats"
        view.backgroundColor = DemoPalette.background
        installLoadingState()
        Task { await installPicker() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    private func installLoadingState() {
        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.color = DemoPalette.red
        activity.startAnimating()
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "Authorising the hosted seat map…"
        loadingLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [activity, loadingLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.accessibilityIdentifier = "desipass-picker-loading"
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 28
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -28
            ),
        ])
    }

    private func installPicker() async {
        guard let eventKey = event.seatEventKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !eventKey.isEmpty else {
            showFailure("This event has no SeatLayer map configured.")
            return
        }

        do {
            let access = try await DesiPassClient.shared.makeSeatLayerAccess(eventId: event.id)
            var configuration = SeatLayerConfiguration(
                event: eventKey,
                apiBase: access.apiBase,
                locale: supportedLocale,
                currency: event.currency ?? "EUR"
            )
            configuration.buyerAccessTokenProvider = access.provider
            configuration.hostInfo = [
                "app": "SeatLayerDemo/1.0",
                "journey": "desipass-native-picker",
            ]

            let options = SeatLayerPickerOptions(
                layout: .phone,
                confirmSelection: true,
                holdTtlMs: 15 * 60 * 1_000,
                panelInitiallyCollapsed: true,
                refreshOnResume: true,
                announceHoldLapse: true
            )
            let callbacks = SeatLayerPickerCallbacks(
                onReady: { info in
                    NSLog(
                        "[SeatLayerDemo] DesiPass ready protocol=%d mode=%@",
                        info.protocolRevision,
                        info.mode.rawValue
                    )
                },
                onSelectionChanged: { seats in
                    NSLog(
                        "[SeatLayerDemo] DesiPass selection count=%d",
                        seats.count
                    )
                },
                onHoldTransition: { hold, _ in
                    NSLog(
                        "[SeatLayerDemo] DesiPass hold active=%@ owner=%@",
                        (hold?.active ?? false).description,
                        hold?.owner ?? "-"
                    )
                },
                onError: { error in
                    NSLog(
                        "[SeatLayerDemo] DesiPass error code=%@ retryable=%@",
                        error.code,
                        error.isRetryable.description
                    )
                }
            )

            let host = SeatLayerPickerViewController(
                configuration: configuration,
                options: options,
                themeMode: .light,
                strings: SeatLayerPickerStrings(localeIdentifier: supportedLocale),
                callbacks: callbacks,
                onCheckout: { [weak self] handoff in
                    guard let self else { return }
                    checkoutInvocationCount += 1
                    let quantity = handoff.lineItems.reduce(0) { $0 + $1.quantity }
                    NSLog(
                        "[SeatLayerDemo] DesiPass checkout callback=%d lines=%d quantity=%d currency=%@ total=%.2f",
                        checkoutInvocationCount,
                        handoff.lineItems.count,
                        quantity,
                        handoff.currency,
                        handoff.total
                    )
                    showCheckoutReceipt(handoff)
                },
                onClose: { [weak self] in
                    self?.navigationController?.setNavigationBarHidden(false, animated: true)
                    self?.navigationController?.popViewController(animated: true)
                }
            )
            pickerHost = host
            activity.superview?.removeFromSuperview()

            addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            host.view.accessibilityIdentifier = "desipass-native-picker"
            view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            host.didMove(toParent: self)
            setNeedsStatusBarAppearanceUpdate()
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    private var supportedLocale: String {
        let language = Locale.preferredLanguages.first?
            .split(separator: "-")
            .first
            .map(String.init) ?? "en"
        return ["en", "de", "fr", "es", "ar"].contains(language) ? language : "en"
    }

    private func showFailure(_ message: String) {
        activity.stopAnimating()
        loadingLabel.text = message
        loadingLabel.textColor = DemoPalette.red
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    private func showCheckoutReceipt(_ handoff: SeatLayerPickerCheckoutHandoff) {
        let receipt = DesiPassCheckoutReceiptViewController(
            event: event,
            handoff: handoff,
            callbackCount: checkoutInvocationCount,
            onDone: { [weak self] in
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
                self?.navigationController?.popToRootViewController(animated: true)
            }
        )
        receipt.modalPresentationStyle = .fullScreen
        present(receipt, animated: true)
    }
}

// MARK: - Host checkout receipt

@MainActor
private final class DesiPassCheckoutReceiptViewController: UIViewController {
    private let event: DesiPassEvent
    private let handoff: SeatLayerPickerCheckoutHandoff
    private let callbackCount: Int
    private let onDone: () -> Void

    init(
        event: DesiPassEvent,
        handoff: SeatLayerPickerCheckoutHandoff,
        callbackCount: Int,
        onDone: @escaping () -> Void
    ) {
        self.event = event
        self.handoff = handoff
        self.callbackCount = callbackCount
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DemoPalette.background
        view.accessibilityIdentifier = "desipass-checkout-receipt"
        view.accessibilityViewIsModal = true
        buildUI()
    }

    private func buildUI() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        check.tintColor = DemoPalette.success
        check.contentMode = .scaleAspectFit
        check.translatesAutoresizingMaskIntoConstraints = false
        check.heightAnchor.constraint(equalToConstant: 66).isActive = true

        let eyebrow = makeLabel(
            textStyle: .caption1,
            weight: .bold,
            color: DemoPalette.success
        )
        eyebrow.text = "HOST CHECKOUT HANDOFF"
        eyebrow.textAlignment = .center

        let heading = makeLabel(textStyle: .title1, weight: .bold, lines: 3)
        heading.text = event.title
        heading.textAlignment = .center

        let total = makeLabel(textStyle: .largeTitle, weight: .bold)
        total.text = DemoFormat.money(handoff.total, currency: handoff.currency)
        total.textAlignment = .center
        total.accessibilityIdentifier = "desipass-checkout-total"

        let quantity = handoff.lineItems.reduce(0) { $0 + $1.quantity }
        let summary = makeLabel(textStyle: .headline, weight: .semibold, lines: 2)
        summary.text = "\(quantity) \(quantity == 1 ? "ticket" : "tickets") · callback \(callbackCount)"
        summary.textAlignment = .center

        let details = makeLabel(textStyle: .body, color: DemoPalette.muted, lines: 8)
        details.text = handoff.lineItems.map { line in
            let price = DemoFormat.money(line.unitPrice, currency: line.currency)
            let tier = line.tierName ?? line.tierId
            return [
                "\(line.quantity)× \(line.displayLabel ?? line.label)",
                tier,
                price,
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
        }
        .joined(separator: "\n")
        details.textAlignment = .center
        details.accessibilityIdentifier = "desipass-checkout-lines"

        let note = makeLabel(textStyle: .footnote, color: DemoPalette.muted, lines: 4)
        note.text = "The real hosted widget transferred the test hold to this native host. Payment and booking are intentionally outside this SDK demo."
        note.textAlignment = .center

        let cardStack = UIStackView(
            arrangedSubviews: [check, eyebrow, heading, total, summary, details, note]
        )
        cardStack.axis = .vertical
        cardStack.alignment = .fill
        cardStack.spacing = 14
        cardStack.isLayoutMarginsRelativeArrangement = true
        cardStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 28,
            leading: 22,
            bottom: 28,
            trailing: 22
        )
        cardStack.backgroundColor = .white
        cardStack.layer.cornerRadius = 22
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(cardStack)

        let doneButton = makePrimaryButton(title: "BACK TO EVENTS")
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.accessibilityIdentifier = "desipass-checkout-done"
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        let bottomBar = UIView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = .white
        view.addSubview(bottomBar)
        bottomBar.addSubview(doneButton)

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = DemoPalette.line
        bottomBar.addSubview(divider)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            cardStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 28),
            cardStack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            cardStack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            cardStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -28),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.topAnchor.constraint(equalTo: doneButton.topAnchor, constant: -12),

            divider.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            divider.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            doneButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            doneButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
            doneButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
            doneButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    @objc private func done() {
        dismiss(animated: true, completion: onDone)
    }
}
