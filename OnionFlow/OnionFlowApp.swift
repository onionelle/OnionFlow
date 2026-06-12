
import AppKit
import SwiftUI

// AppDelegate 负责 AppKit 生命周期、顶部 panel 创建和跨层回调装配。
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = IslandViewModel()
    let musicViewModel = MusicPlayerViewModel()
    let quickLaunchViewModel = QuickLaunchViewModel()
    let temporaryTrayViewModel = TemporaryTrayViewModel()
    lazy var remoteControlServer = RemoteControlServer(musicViewModel: musicViewModel)
    lazy var folderMonitor = MusicFolderMonitor()
    var panelController: FloatingPanelController?
    let settingsController = SettingsWindowController()
    private var didPersistMusicStateForTermination = false
    private var wakeObserver: NSObjectProtocol?
    private var userDefaultsObserver: NSObjectProtocol?

    deinit {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        settingsController.onVisibilityChange = { [weak self] isPresented in
            self?.viewModel.setSettingsPresented(isPresented)
        }
        viewModel.onOpenSettings = { [weak self] in
            self?.toggleSettings()
        }
        viewModel.onIsExpandedChange = { [weak self] isExpanded in
            guard !isExpanded, self?.viewModel.isSettingsPresented == true else { return }
            self?.settingsController.close()
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
            quickLaunchViewModel: quickLaunchViewModel,
            temporaryTrayViewModel: temporaryTrayViewModel
        )
        panelController?.show()
        if UserDefaults.standard.object(forKey: "remoteControlEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "remoteControlEnabled")
        }
        if UserDefaults.standard.bool(forKey: "remoteControlEnabled") {
            remoteControlServer.start()
        }
        if UserDefaults.standard.object(forKey: "autoListenEnabled") == nil {
            UserDefaults.standard.set(false, forKey: "autoListenEnabled")
        }
        if UserDefaults.standard.object(forKey: "autoListenPath") == nil {
            UserDefaults.standard.set("~/Music", forKey: "autoListenPath")
        }
        
        folderMonitor.onAudioFilesAdded = { [weak self] urls in
            self?.musicViewModel.addFilesOrDirectoriesToPlaylist(from: urls)
        }
        
        if UserDefaults.standard.bool(forKey: "autoListenEnabled") {
            let path = UserDefaults.standard.string(forKey: "autoListenPath") ?? "~/Music"
            folderMonitor.start(path: path)
        }
        
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let remoteEnabled = UserDefaults.standard.bool(forKey: "remoteControlEnabled")
            if remoteEnabled && !(self?.remoteControlServer.isRunning ?? false) {
                self?.remoteControlServer.start()
            } else if !remoteEnabled && (self?.remoteControlServer.isRunning ?? true) {
                self?.remoteControlServer.stop()
            }
            
            let autoListenEnabled = UserDefaults.standard.bool(forKey: "autoListenEnabled")
            let path = UserDefaults.standard.string(forKey: "autoListenPath") ?? "~/Music"
            
            if autoListenEnabled {
                // If it's already running on the same path, do nothing. But since we just want to ensure it runs correctly,
                // we can just call start() which already calls stop() internally.
                // However, to avoid restarting on every unrelated UserDefaults change, we should track the current state.
                // Or simply let folderMonitor track its current path.
                self?.folderMonitor.start(path: path)
            } else {
                self?.folderMonitor.stop()
            }
        }
        restorePreferredAudioOutput()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restorePreferredAudioOutput()
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        remoteControlServer.stop()
        folderMonitor.stop()
        persistMusicStateForTermination()
    }
    func persistMusicStateAndQuit() {
        persistMusicStateForTermination()
        NSApp.terminate(nil)
    }
    func showSettings() {
        settingsController.show(alignedTo: panelController?.currentSettingsAnchorFrame)
    }
    func toggleSettings() {
        settingsController.toggle(alignedTo: panelController?.currentSettingsAnchorFrame)
    }
    private func quitApp() {
        persistMusicStateAndQuit()
    }
    private func restorePreferredAudioOutput() {
        let uid = UserDefaults.standard.string(forKey: "preferredAudioOutputDeviceUID") ?? ""
        AudioOutputDeviceService.restorePreferredOutputDevice(uid: uid)
    }
    private func persistMusicStateForTermination() {
        guard !didPersistMusicStateForTermination else { return }
        didPersistMusicStateForTermination = true
        musicViewModel.persistCurrentStateOnQuit()
    }
}

struct MenuBarContent: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @ObservedObject var remoteControlServer: RemoteControlServer
    let showSettings: () -> Void
    let quitApp: () -> Void

    var body: some View {
        if let track = musicViewModel.currentTrack {
            let stateSymbol = musicViewModel.state == .playing ? "pause.fill" : "play.fill"
            let artistText = track.artist != nil ? " - \(track.artist!)" : ""

            Button(action: {
                musicViewModel.togglePlayPause()
            }) {
                Label("正在播放: \(track.title)\(artistText)", systemImage: stateSymbol)
            }

            Button(action: {
                musicViewModel.playPreviousTrack()
            }) {
                Label("上一首", systemImage: "backward.fill")
            }

            Button(action: {
                musicViewModel.playNextTrack()
            }) {
                Label("下一首", systemImage: "forward.fill")
            }

            Divider()
        }

        Text("遥控器: \(remoteControlServer.localURL)")
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Button(action: {
            viewModel.toggleExpanded()
        }) {
            Label(
                viewModel.isExpanded ? "收起 Onion 面板" : "展开 Onion 面板",
                systemImage: viewModel.isExpanded ? "chevron.up.circle" : "chevron.down.circle"
            )
        }
        .keyboardShortcut("e", modifiers: .command)

        Button(action: {
            showSettings()
        }) {
            Label("设置与偏好...", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button(action: {
            quitApp()
        }) {
            Label("退出 Onion", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

@main
struct OnionFlowApp: App {
    // SwiftUI App 生命周期通过 adaptor 接入 AppKit delegate，顶部 NSPanel 仍由 AppKit 管理。
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        MenuBarExtra("Onion", image: "StatusBarOnionMark") {
            MenuBarContent(
                viewModel: appDelegate.viewModel,
                musicViewModel: appDelegate.musicViewModel,
                remoteControlServer: appDelegate.remoteControlServer,
                showSettings: { appDelegate.showSettings() },
                quitApp: { appDelegate.persistMusicStateAndQuit() }
            )
        }
        .menuBarExtraStyle(.menu)
    }
}
