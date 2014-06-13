SRC_DIR = ..

SELECT_FILES = $(SRC_DIR)/selectFiles.rb collect_files.yaml
RBPACK = ../../../ruby_sfx/build_linux/rbpack
CUR_BUILD_NUM = ../../../../cur_build_num
BUILD_DIR = build_dir
MIQHOST_DIR = $(SRC_DIR)/miqhost
MIQCMD_DIR = $(SRC_DIR)/miq-cmd
TARGET = miq-host-cmd

TFP = $(shell pwd)/$(TARGET)

$(TARGET): FRC
	rm -f $(TARGET)
	rm -rf $(BUILD_DIR)
	cp $(RBPACK) $(TARGET)
	cd $(MIQHOST_DIR); cp $(CUR_BUILD_NUM) revision.svn 2> /dev/null || svn info | grep "^Revision:" | cut -d " " -f2 | tr -d "\n\r" > revision.svn
	ruby $(SELECT_FILES)
	cd $(BUILD_DIR); zip -A -r $(TFP) *

clean:
	rm -f $(TARGET)
	rm -rf $(BUILD_DIR)

FRC: