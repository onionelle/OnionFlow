
import AppKit
import SwiftUI

// AppDelegate 负责 AppKit 生命周期、顶部 panel 创建和跨层回调装配。
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = IslandViewModel()
    let musicViewModel = MusicPlayerViewModel()
    let quickLaunchViewModel = QuickLaunchViewModel()
    var panelController: FloatingPanelController?
    let settingsController = SettingsWindowController()
    private var didPersistMusicStateForTermination = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        viewModel.onOpenSettings = { [weak self] in
            self?.settingsController.show()
        }
        viewModel.onRequestQuit = { [weak self] in
            self?.quitApp()
        }
        // 打开 NSOpenPanel 时由文件选择器自身置顶；这里保留对称回调，关闭后恢复 island 层级。
        musicViewModel.onWillOpenFilePicker = { [weak self] in
            self?.panelController?.lowerPanelForSystemModal()
        }
        musicViewModel.onDidCloseFilePicker = { [weak self] in
            self?.panelController?.restorePanelAfterSystemModal()
        }
        panelController = FloatingPanelController(
            viewModel: viewModel,
            musicViewModel: musicViewModel,
            quickLaunchViewModel: quickLaunchViewModel
        )
        panelController?.show()
    }
    func applicationWillTerminate(_ notification: Notification) {
        persistMusicStateForTermination()
    }
    func persistMusicStateAndQuit() {
        persistMusicStateForTermination()
        NSApp.terminate(nil)
    }
    private func quitApp() {
        persistMusicStateAndQuit()
    }
    private func persistMusicStateForTermination() {
        guard !didPersistMusicStateForTermination else { return }
        didPersistMusicStateForTermination = true
        musicViewModel.persistCurrentStateOnQuit()
    }
}

@main
struct NookFlowApp: App {
    // SwiftUI App 生命周期通过 adaptor 接入 AppKit delegate，顶部 NSPanel 仍由 AppKit 管理。
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        MenuBarExtra("NookFlow", systemImage: "capsule.portrait") {
            Button(appDelegate.viewModel.isExpanded ? "Collapse Panel" : "Expand Panel") {
                appDelegate.viewModel.toggleExpanded()
            }
            Divider()
            Button("Settings...") {
                appDelegate.settingsController.show()
            }

            Divider()
            Button("Quit") {
                appDelegate.persistMusicStateAndQuit()
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
