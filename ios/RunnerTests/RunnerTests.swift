import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testAppDelegateWindowExists() {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    XCTAssertNotNil(appDelegate.window, "App delegate should have a window")
  }

  func testAppDelegateWindowHasRootViewController() {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    XCTAssertNotNil(appDelegate.window?.rootViewController, "Window should have a root view controller")
  }

}
