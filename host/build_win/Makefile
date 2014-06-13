SRC_DIR = ..

SELECT_FILES = $(SRC_DIR)/selectFiles.rb collect_files.yaml

# This is provided by the mingw32-cfme-ruby-sfx RPM
SFX = /usr/i686-w64-mingw32/sys-root/mingw/bin/ruby_sfx.exe

# This directory tree is created by the cfme spec file at RPM build
# time.  When this Makefile is invoked, it is expected to contain a
# cross-compiled ruby and all needed gems.  Also any DLLs needed by
# extensions (e.g. libssl, libyaml, etc.).  Override this on the
# command line to point at your own ruby dist if needed.
RUBY_DIR = ../../mingw-ruby

BUILD_DIR = build_dir
TARGET = miq-host-cmd.exe

TFP = $(shell pwd)/$(TARGET)
RBPACK = $(shell pwd)/rbpack.zip

$(TARGET):
	rm -f $(TARGET)
	rm -rf $(BUILD_DIR)
	ruby $(SELECT_FILES)

#	We need to remove git:// sources from the Gemfile, since we
#	really don't want to bundle in a build of git.  None of the
#	gems that are made available in $(RUBY_DIR) should be git
#	gems.
	sed -i 's/, :git.*//' $(BUILD_DIR)/host/Gemfile

	cp -r $(RUBY_DIR)/* $(BUILD_DIR)
	cd $(BUILD_DIR); zip -r $(RBPACK) *
	cat $(SFX) $(RBPACK) > $(TARGET)
	zip -A $(TARGET)

clean:
	rm -f $(TARGET) $(RBPACK)
	rm -rf $(BUILD_DIR)

.PHONY: clean

