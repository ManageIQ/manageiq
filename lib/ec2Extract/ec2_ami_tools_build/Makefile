VERSION = 1.4.0.7
NAME = ec2-ami-tools
TARGET = $(NAME)-INSTALL
TAR_FILE = $(NAME).tar
TOOLS_DIR = ../../../..
PWD = $(CURDIR)

$(TARGET): FRC
	rm -f $(TARGET)
	rm -f $(TAR_FILE)
	cd $(TOOLS_DIR); tar czvf $(PWD)/$(TAR_FILE) $(NAME)-$(VERSION)
	cat sfx-header $(TAR_FILE) > $(TARGET)
	chmod 755 $(TARGET)
	
clean:
	rm -f $(TAR_FILE)
	
clobber: clean
	rm -f $(TARGET)

FRC:
