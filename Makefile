TARGET := iphone:clang:latest:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = TikTok

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = P6YTOK

P6YTOK_FILES = Tweak.x P6YMediaQuality.x P6YLiveZoom.x P6YFollowerTracker.x P6YManager.m P6YDownloadManager.m P6YDownloadManager+FullQuality.m SettingsViewController.m
P6YTOK_FRAMEWORKS = UIKit Foundation Photos QuartzCore
P6YTOK_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types -Wno-undeclared-selector

include $(THEOS_MAKE_PATH)/tweak.mk
