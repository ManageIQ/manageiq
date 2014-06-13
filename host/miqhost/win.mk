SELECT_FILES = selectFiles.rb win_collect_files.yaml
BUILDREV = svn_build_rev.rb
RBPACK = ../../../ruby_sfx/rbpack.win
BUILD_DIR = build_dir
TARGET = miqhost.exe

TFP = $(shell pwd)/$(TARGET)

$(TARGET): FRC
	rm -f $(TARGET)
	rm -rf $(BUILD_DIR)
	cp $(RBPACK) $(TARGET)
	ruby $(BUILDREV)
	ruby $(SELECT_FILES)
	cd $(BUILD_DIR); zip -A -r $(TFP) *

FRC: