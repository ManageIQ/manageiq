SELECT_FILES = selectFiles.rb linux_collect_files.yaml
RBPACK = ../../../../ruby_sfx/ruby_sfx_app_only
BUILD_DIR = build_dir_linux
ZIPED_FILES = ziped_files.zip
TARGET = ec2_extract
TAR_FILE = $(TARGET).tar
INSTALLER = $(TARGET)_install
ZIP = zip

$(TARGET): $(ZIPED_FILES) FRC
	rm -f $(TARGET)
	rm -f $(TAR_FILE)
	rm -rf $(BUILD_DIR)
	cat $(RBPACK) $(ZIPED_FILES) > $(TARGET)
	$(ZIP) -A $(TARGET)
	chmod 755 $(TARGET)
	ruby $(SELECT_FILES)
	cp $(TARGET) $(BUILD_DIR)
	cd $(BUILD_DIR); tar czvf ../$(TAR_FILE) *
	cat sfx-header $(TAR_FILE) > $(INSTALLER)
	chmod 755 $(INSTALLER)
	
$(ZIPED_FILES): init.rb
	$(ZIP) $(ZIPED_FILES) init.rb
	
clean:
	rm -rf $(BUILD_DIR)
	rm -f $(TAR_FILE)
	rm -f $(TARGET)
	
clobber: clean
	rm -f $(INSTALLER)

FRC:
