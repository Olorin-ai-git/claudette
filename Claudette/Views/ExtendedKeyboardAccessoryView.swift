import UIKit

final class ExtendedKeyboardAccessoryView: UIView {
    private let onKeyTapped: (ArraySlice<UInt8>) -> Void
    private let onDismissKeyboard: () -> Void
    private let config: AppConfiguration

    init(
        config: AppConfiguration,
        onKeyTapped: @escaping (ArraySlice<UInt8>) -> Void,
        onDismissKeyboard: @escaping () -> Void
    ) {
        self.config = config
        self.onKeyTapped = onKeyTapped
        self.onDismissKeyboard = onDismissKeyboard
        let height = config.keyboardAccessoryHeight
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height))
        autoresizingMask = .flexibleWidth
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupView() {
        backgroundColor = UIColor(hex: config.keyboardAccessoryBackgroundColor)

        // Dismiss button — fixed on the right, outside the scroll area
        let dismissButton = UIButton(type: .system)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.setImage(
            UIImage(systemName: "keyboard.chevron.compact.down"),
            for: .normal
        )
        dismissButton.tintColor = UIColor(hex: config.keyboardAccessoryButtonTextColor)
        dismissButton.backgroundColor = UIColor(hex: config.keyboardAccessoryButtonColor)
        dismissButton.layer.cornerRadius = 6
        dismissButton.addTarget(self, action: #selector(dismissKeyboard), for: .touchUpInside)
        addSubview(dismissButton)

        // Thin separator
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.separator
        addSubview(separator)

        NSLayoutConstraint.activate([
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 36),
            dismissButton.heightAnchor.constraint(equalToConstant: config.keyboardAccessoryHeight - 10),

            separator.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -6),
            separator.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            separator.widthAnchor.constraint(equalToConstant: 0.5),
        ])

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: separator.leadingAnchor, constant: -4),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        scrollView.addSubview(stackView)

        let stackPadding: CGFloat = 8
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: stackPadding),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -stackPadding),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        let buttonColor = UIColor(hex: config.keyboardAccessoryButtonColor)
        let textColor = UIColor(hex: config.keyboardAccessoryButtonTextColor)

        for (index, buttonConfig) in config.keyboardAccessoryButtons.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(buttonConfig.label, for: .normal)
            button.setTitleColor(textColor, for: .normal)
            button.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
            button.backgroundColor = buttonColor
            button.layer.cornerRadius = 6

            let minWidth: CGFloat = buttonConfig.label.count > 3 ? 52 : 36
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth).isActive = true
            button.heightAnchor.constraint(equalToConstant: config.keyboardAccessoryHeight - 10).isActive = true

            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < config.keyboardAccessoryButtons.count else { return }

        let bytes = config.keyboardAccessoryButtons[index].byteSequence
        onKeyTapped(bytes[...])

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    @objc private func dismissKeyboard() {
        onDismissKeyboard()
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
