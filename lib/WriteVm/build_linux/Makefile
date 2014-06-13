SELECT_FILES = selectFiles.rb linux_collect_files.yaml
RBPACK = ../../../../ruby_sfx/ruby_sfx_app_only
BUILD_DIR = build_dir_linux
ZIPED_FILES = ziped_files.zip
TARGET = vmAutomate
ZIP = zip

$(TARGET): $(ZIPED_FILES) FRC
	rm -f $(TARGET)
	rm -f wvm.tar
	rm -rf $(BUILD_DIR)
	cat $(RBPACK) $(ZIPED_FILES) > $(TARGET)
	$(ZIP) -A $(TARGET)
	chmod 755 $(TARGET)
	ruby $(SELECT_FILES)
	cp $(TARGET) $(BUILD_DIR)
	cd $(BUILD_DIR); tar czvf ../wvm.tar *
	cat sfx-header wvm.tar > wvm_install
	chmod 755 wvm_install
	
$(ZIPED_FILES): init.rb
	$(ZIP) $(ZIPED_FILES) init.rb

FRC:
