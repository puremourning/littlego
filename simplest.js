var wd = require("wd");
var assert = require("assert");
var appPath = "/Users/patrick/dev/littlego/DerivedData/Little Go/Build/Products/Debug-iphonesimulator/Little Go.app";

// Instantiate a new browser session
var browser = wd.remote("localhost", 4723);

// See whats going on
browser.on("status", function(info) {
  console.log('\x1b[36m%s\x1b[0m', info);
});

browser.on("command", function(meth, path, data) {
  console.log(' > \x1b[33m%s\x1b[0m: %s', meth, path, data || '');
});

var capabilities = {
    device: "iPhone Simulator",
    browserName: "",
    platform: "Mac",
    version: "6.1",
    app: appPath,
    name: "Little Go: with WD",
    newCommandTimeout: 60
//    device: ""
//    , name: "Appium: with WD"
//    , platform: "Mac"
//    , app: appURL
//    , version: "6.0"
//    , browserName: "iOS"
//    , newCommandTimeout: 60
  }

function clickButton(err, btns)
{
  if (btns.length === 0)
  {
    console.log("no button found");
    quitBrowser();
  }
  else
  {
    btns[0].click(quitBrowser);
  }
}

function quitBrowser(err)
{
  browser.quit();
}

// Run the test
browser
  .chain()
  .init(capabilities)
  .elementsByName("computerPlayButton", clickButton);
