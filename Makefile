ARCHS = arm64e
TARGET = iphone:clang::14.0
export ROOTLESS = 1
NO_CODESIGN := 1

THEOS ?= $(shell echo $$THEOS)
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = auxsix
auxsix_FILES = Tweak.xm \
    common/AuxConfig.xm \
    common/AuxSettingController.xm \
    modules/AuxPreventRevoke.xm \
    modules/AuxRedEnvelop.xm \
    modules/AuxAdBlock.xm \
    modules/AuxRoundCorner.xm \
    modules/AuxHideDevice.xm \
    modules/AuxTTS.xm

# 编译时能找到 Headers/WCPluginsHeader.h 和 common/*.h
auxsix_CFLAGS = -I$(THEOS_PROJECT_DIR) -I$(THEOS_PROJECT_DIR)/Headers

auxsix_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk
