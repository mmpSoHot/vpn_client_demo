import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    
    // 获取屏幕尺寸
    let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
    
    // 计算窗口居中位置
    let windowWidth: CGFloat = 350
    let windowHeight: CGFloat = 750
    let x = (screenFrame.width - windowWidth) / 2
    let y = (screenFrame.height - windowHeight) / 2
    
    let windowFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    
    // 设置窗口为固定大小
    self.styleMask = [.titled, .closable, .miniaturizable]
    self.isResizable = false
    self.setContentSize(NSSize(width: windowWidth, height: windowHeight))

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
