SELECT_FILES = selectFiles.rb
RBPACK = ../../../ruby_sfx/rbpack.linux
BUILD_DIR = build_dir
TARGET = miq-cmd

TFP = $(shell pwd)/$(TARGET)

$(TARGET): FRC
	rm -f $(TARGET)
	rm -rf $(BUILD_DIR)
	cp $(RBPACK) $(TARGET)
	ruby $(SELECT_FILES)
	cd $(BUILD_DIR); zip -A -r $(TFP) *

FRC: