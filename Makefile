TARGET := iphone:clang:latest:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = TikTok

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = P6YTOK

P6YTOK_FILES = P6YTOK.x $(wildcard *.m JGProgressHUD/*.m)
P6YTOK_FRAMEWORKS = UIKit Foundation CoreGraphics Photos CoreServices SystemConfiguration SafariServices Security QuartzCore LocalAuthentication
P6YTOK_PRIVATE_FRAMEWORKS = Preferences
P6YTOK_EXTRA_FRAMEWORKS = Cephei CepheiPrefs CepheiUI
P6YTOK_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types

include $(THEOS_MAKE_PATH)/tweak.mk
