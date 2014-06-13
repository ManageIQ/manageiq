SRC_DIR = .

SELECT_FILES = $(SRC_DIR)/selectFiles.rb collect_files.yaml
RBPACK = ../../../../../ruby_sfx_rvm/build_linux/rbpack
BUILD_DIR = build_dir
TARGET = ../local-extractor32

TFP = $(shell pwd)/$(TARGET)

$(TARGET): FRC
	rm -f $(TARGET)
	rm -rf $(BUILD_DIR)
	cp $(RBPACK) $(TARGET)
	ruby $(SELECT_FILES)
	cd $(BUILD_DIR); zip -A -r $(TFP) *

clean:
	rm -rf $(BUILD_DIR)
	
clobber: clean
	rm -f $(TARGET)

FRC:
