import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .white

        let environment = ProcessInfo.processInfo.environment
        let apiKey = environment["DESIPASS_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let usesDesiPass = apiKey?.isEmpty == false
            && environment["SEATLAYER_DIRECT_DEMO"] != "1"

        if usesDesiPass {
            let navigationController = UINavigationController(
                rootViewController: DesiPassDemoViewController()
            )
            navigationController.navigationBar.prefersLargeTitles = true
            navigationController.navigationBar.tintColor = DemoPalette.red

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            appearance.shadowColor = DemoPalette.line
            appearance.titleTextAttributes = [.foregroundColor: DemoPalette.ink]
            appearance.largeTitleTextAttributes = [.foregroundColor: DemoPalette.ink]
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
            window.rootViewController = navigationController
        } else {
            window.rootViewController = DemoViewController()
        }
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
