#if DEBUG
import CorbieCore
import SwiftUI

struct ScreenshotModeRoot: View {
    let screenshotMode: ScreenshotModeSwitch
    let appState: AppState

    var body: some View {
        Group {
            if let environment = screenshotMode.active {
                ThemedRoot(appState: appState, environment: environment)
                    .id(ObjectIdentifier(environment))
                    .task(id: ObjectIdentifier(environment)) {
                        await screenshotMode.bootstrap(environment)
                    }
            } else {
                LaunchPlaceholderView()
                    .corbieTheme(screenshotMode.real.theme.activeTheme)
            }
        }
        .environment(screenshotMode)
    }
}
#endif
