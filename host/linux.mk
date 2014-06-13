SELECT_FILES = selectFiles.rb linux_collect_files.yaml
BUILDREV = svn_build_rev.rb
RBPACK = ../../ruby_sfx/rbpack.linux
BUILD_DIR = build_dir_linux
MIQHOST_DIR = miqhost
MIQCMD_DIR = miq-cmd
TARGET = miq-host-cmd

TFP = $(shell pwd)/$(TARGET)

$(TARGET): FRC
	rm -f $(TARGET)
	rm -rf $(BUILD_DIR)
	cp $(RBPACK) $(TARGET)
	cd $(MIQHOST_DIR); ruby $(BUILDREV)
	ruby $(SELECT_FILES)
	cd $(BUILD_DIR); zip -A -r $(TFP) *

FRC: