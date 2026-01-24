import XCTest

final class OrdinatioUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func noteField(in app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["TransactionNoteField"]
        if field.exists { return field }
        return app.textViews["TransactionNoteField"]
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let toolbarDone = app.buttons["Done"]
        if toolbarDone.waitForExistence(timeout: 1), toolbarDone.isHittable {
            toolbarDone.tap()
            return
        }

        let keyboardDone = app.keyboards.buttons["Done"]
        if keyboardDone.exists {
            keyboardDone.tap()
            return
        }

        app.tap()
    }

    private func enterAmount(_ value: String, in app: XCUIApplication) {
        for character in value {
            let key: XCUIElement
            switch character {
            case ".":
                key = app.buttons["TransactionKeypadDecimal"]
            case "0"..."9":
                key = app.buttons["TransactionKeypadDigit\(character)"]
            default:
                XCTFail("Unsupported amount character: \(character)")
                return
            }
            XCTAssertTrue(key.waitForExistence(timeout: 5))
            key.tap()
        }
    }

    func testAddAndEditTransactionFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchArguments += [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US_POSIX",
            "-AppleTimeZone",
            "UTC",
        ]
        app.launch()

        let logNavBar = app.navigationBars["Log"]
        XCTAssertTrue(logNavBar.waitForExistence(timeout: 10))

        // Support both the system TabView tab item ("Add") and a custom tab bar button ("Add Transaction").
        let addTransactionButton = app.buttons["Add Transaction"]
        if addTransactionButton.waitForExistence(timeout: 1) {
            addTransactionButton.tap()
        } else {
            let addTab = app.tabBars.buttons["Add"]
            XCTAssertTrue(addTab.waitForExistence(timeout: 10))
            addTab.tap()
        }

        enterAmount("12.34", in: app)

        let noteInput = noteField(in: app)
        XCTAssertTrue(noteInput.waitForExistence(timeout: 5))
        noteInput.tap()
        noteInput.typeText("UITest Transaction 1")
        dismissKeyboard(in: app)

        let saveButton = app.buttons["TransactionKeypadSave"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // If "Add" is implemented as a tab (not a modal), switch back to the Log tab to verify the transaction appears.
        let logTab = app.tabBars.buttons["Log"]
        if logTab.waitForExistence(timeout: 2) {
            logTab.tap()
        }

        let createdCell = app.staticTexts["UITest Transaction 1"].firstMatch
        XCTAssertTrue(createdCell.waitForExistence(timeout: 10))

        createdCell.tap()

        let noteInput2 = noteField(in: app)
        XCTAssertTrue(noteInput2.waitForExistence(timeout: 5))
        noteInput2.tap()

        let clearNoteButton = app.buttons["Clear note"]
        if clearNoteButton.waitForExistence(timeout: 1) {
            clearNoteButton.tap()
        } else if let currentValue = noteInput2.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            noteInput2.typeText(deleteString)
        }
        noteInput2.typeText("UITest Transaction 2")
        dismissKeyboard(in: app)

        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["UITest Transaction 2"].firstMatch.waitForExistence(timeout: 10))
    }
}
