import Foundation

@main
struct MenuBarSearchPolicyTests {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ description: String) {
            precondition(condition, description)
            checks += 1
        }

        let controlCenter = "com.apple.controlcenter"
        for title: String? in [nil, "", "控制中心", "UnknownModule"] {
            check(MenuBarSearchPolicy.displayName(namespace: controlCenter, title: title, applicationName: "控制中心") == nil,
                  "Unknown system modules must be omitted, not collapsed into Control Center")
        }
        check(MenuBarSearchPolicy.displayName(namespace: controlCenter, title: "BentoBox", applicationName: "Control Center") == "控制中心", "Recognize the real Control Center item")
        check(MenuBarSearchPolicy.displayName(namespace: controlCenter, title: "Bluetooth", applicationName: "Control Center") == "蓝牙", "Localize known modules")
        check(MenuBarSearchPolicy.displayName(namespace: "com.apple.systemuiserver", title: nil, applicationName: "SystemUIServer") == nil, "Omit unnamed SystemUIServer modules")
        check(MenuBarSearchPolicy.displayName(namespace: "com.apple.systemuiserver", title: "TimeMachineMenuExtra.TMMenuExtraHost", applicationName: "SystemUIServer") == "时间机器", "Recognize Sequoia Time Machine")
        check(MenuBarSearchPolicy.displayName(namespace: "org.example.app", title: nil, applicationName: "示例应用") == "示例应用", "Third-party items remain searchable without window titles")
        check(MenuBarSearchPolicy.displayName(namespace: nil, title: nil, applicationName: "Example") == "Example", "A missing bundle identifier must not hide third-party applications")
        check(MenuBarSearchPolicy.matches("Clash Verge", query: "VERGE"), "Native search ignores case")
        check(MenuBarSearchPolicy.matches("Café", query: "cafe"), "Native search handles diacritics")
        check(MenuBarSearchPolicy.matches("快速用户切换", query: "用户"), "Chinese substring search")
        check(MenuBarSearchPolicy.matches("微信", query: " \n "), "Blank queries show all identifiable items")
        check(!MenuBarSearchPolicy.matches("微信", query: "weixin"), "Do not imply pinyin support")
        check(!MenuBarSearchPolicy.matches("Clash Verge", query: "clsh"), "Do not retain fuzzy matching")

        // Equal display names and persistent infos must not imply equal runtime identities.
        let first = MenuBarSearchIdentity(windowID: 100, ownerPID: 10)
        let second = MenuBarSearchIdentity(windowID: 101, ownerPID: 10)
        let restarted = MenuBarSearchIdentity(windowID: 100, ownerPID: 20)
        check(Set([first, second]).count == 2, "Two windows from one process stay distinct")
        check(first != restarted, "Do not activate a reused window ID owned by a restarted process")
        check(MenuBarSearchPolicy.selection(keeping: second, available: [first, second]) == second, "Preserve a valid selection on refresh")
        check(MenuBarSearchPolicy.selection(keeping: first, available: [second, first]) == first, "Preserve selection when rows reorder")
        check(MenuBarSearchPolicy.selection(keeping: first, available: [second]) == second, "Move selection away from a removed or filtered item")
        check(MenuBarSearchPolicy.selection(keeping: first, available: []) == nil, "An empty result has no actionable selection")
        check(MenuBarSearchPolicy.selection(keeping: first, available: [restarted, second]) == restarted, "A replacement receives a fresh identity")
        print("Passed \(checks) search regression checks")
    }
}
