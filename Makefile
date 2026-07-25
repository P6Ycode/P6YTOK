ARCHS = arm64
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = TikTok

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = P6YTOK

P6YTOK_FILES = Tweak.x
P6YTOK_FRAMEWORKS = Foundation UIKit
P6YTOK_CFLAGS = -fobjc-arc
P6YTOK_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk
