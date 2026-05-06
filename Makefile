# RainbowApple — colourful menu-bar apple logo.
#
# Release pipeline delegated to the shared `release.mk` from
# PerpetualBeta/jorvik-release. swiftc project, embedded Sparkle,
# dual-ship (.zip + .pkg).

BUNDLE_NAME      := RainbowApple
BUNDLE_TYPE      := app
PRODUCT_NAME     := RainbowApple.app
BUNDLE_ID        := cc.jorviksoftware.RainbowApple
BUILD_SYSTEM     := swiftc

SWIFT_FRAMEWORKS := Cocoa SwiftUI ServiceManagement
SWIFT_SOURCES    := main.swift \
                    AboutView.swift \
                    RainbowAppleSettingsContent.swift

PACKAGE_TYPE     := zip
ALSO_SHIP_PKG    := true
EMBEDDED_FRAMEWORKS := Sparkle
ENTITLEMENTS     := RainbowApple.entitlements

include ../jorvik-release/release.mk
