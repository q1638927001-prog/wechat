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

auxsix_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk
