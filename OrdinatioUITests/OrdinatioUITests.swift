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

    func testAddAndEditTransactionFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()

        let transactionsNavBar = app.navigationBars["Transactions"]
        XCTAssertTrue(transactionsNavBar.waitForExistence(timeout: 10))

        transactionsNavBar.buttons["Add Transaction"].tap()

        let amountField = app.textFields["TransactionAmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("12.34")

        let noteField = noteField(in: app)
        XCTAssertTrue(noteField.waitForExistence(timeout: 5))
        noteField.tap()
        noteField.typeText("UITest Transaction 1")

        app.navigationBars.buttons["Save"].tap()

        let createdCell = app.staticTexts["UITest Transaction 1"]
        XCTAssertTrue(createdCell.waitForExistence(timeout: 10))

        createdCell.tap()

        let noteField2 = noteField(in: app)
        XCTAssertTrue(noteField2.waitForExistence(timeout: 5))
        noteField2.tap()
        if let currentValue = noteField2.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            noteField2.typeText(deleteString)
        }
        noteField2.typeText("UITest Transaction 2")

        app.navigationBars.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["UITest Transaction 2"].waitForExistence(timeout: 10))
    }
}
