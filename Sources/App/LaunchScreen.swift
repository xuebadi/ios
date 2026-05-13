import UIKit

class LaunchScreen: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#FF6B6B")

        let logoLabel = UILabel()
        logoLabel.text = "🤖 学霸帝AI"
        logoLabel.textColor = .white
        logoLabel.font = .systemFont(ofSize: 32, weight: .bold)
        logoLabel.textAlignment = .center
        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "本地多模态 AI 助手"
        subtitleLabel.textColor = .white.withAlphaComponent(0.85)
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -16),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 8)
        ])
    }
}
