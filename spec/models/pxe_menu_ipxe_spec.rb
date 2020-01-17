RSpec.describe PxeMenuIpxe do
  before do
    @contents = <<-PXEMENU
#!ipxe
menu ManageIQ iPXE Boot Menu
item --gap -- -----Live Images:
item ud1204 Ubuntu 12.04 Desktop x64
#item ud1204_commented_in_menu Ubuntu 12.04 Desktop x64
item ud1204_commented_in_image Ubuntu 12.04 Desktop x64
item --gap
item --gap -- -----MIQ Desktop Auto-Install:
item rhel62dsk RHEL6.2 Desktop AutoInstall - Be Careful
item --gap
item --gap -- -----MIQ Server Auto-Install:
item rhel62host   RHEL6.2 Host
item esxi5  VMware ESXi 5.0.0-----
item --gap
item --gap -- -----Other Stuff:
item reboot    Reboot the Machine
item ipxedemo  iPXE Demo
choose os && goto ${os}

########## MIQ Live Images ##########
:ud1204
kernel http://192.168.252.60/boot/ubuntu-12.04-desktop/casper/vmlinuz vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/boot/ubuntu-12.04-desktop ro root=/dev/nfs -- quiet
initrd http://192.168.252.60/boot/ubuntu-12.04-desktop/casper/initrd.lz
boot

:ud1204_not_in_menu
kernel http://192.168.252.60/boot/ubuntu-12.04-desktop/casper/vmlinuz vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/boot/ubuntu-12.04-desktop ro root=/dev/nfs -- quiet
initrd http://192.168.252.60/boot/ubuntu-12.04-desktop/casper/initrd.lz
boot

:ud1204_commented_in_menu
kernel http://192.168.252.60/boot/ubuntu-12.04-desktop/casper/vmlinuz vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/boot/ubuntu-12.04-desktop ro root=/dev/nfs -- quiet
initrd http://192.168.252.60/boot/ubuntu-12.04-desktop/casper/initrd.lz
boot

:ud1204_commented_in_image
#kernel http://192.168.252.60/boot/ubuntu-12.04-desktop/casper/vmlinuz vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/boot/ubuntu-12.04-desktop ro root=/dev/nfs -- quiet
#initrd http://192.168.252.60/boot/ubuntu-12.04-desktop/casper/initrd.lz
#boot

########## MIQ Desktop Images ##########
:rhel62dsk
kernel http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/rhel6.2-desktop.ks.cfg ksdevice=00:50:56:91:79:d5
initrd http://192.168.252.60/ipxe/rhel6.2-desktop/initrd.img
boot

########## MIQ Server Images ##########
:rhel62host
kernel http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/rhel6.2-host.ks.cfg
initrd http://192.168.252.60/ipxe/rhel6.2-desktop/initrd.img
boot

########## Other Stuff ##########
:reboot
reboot

:ipxedemo
chain http://boot.ipxe.org/demo/boot.php
PXEMENU

    @contents2 = <<-PXEMENU
#!ipxe
menu ManageIQ iPXE Boot Menu
item --gap -- -----Live Images:
item rhel62host   RHEL6.2 Host
choose os && goto ${os}

########## MIQ Server Images ##########
:rhel62host
kernel http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/rhel6.2-host.ks.cfg
initrd http://192.168.252.60/ipxe/rhel6.2-desktop/initrd.img
boot
PXEMENU
  end

  it ".parse_contents" do
    expect(described_class.parse_contents(@contents).length).to eq(3)
    expect(described_class.parse_contents(@contents).all? { |h| h.kind_of?(Hash) }).to be_truthy
  end

  it ".parse_kernel" do
    k = "http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/rhel6.2-host.ks.cfg ksdevice=00:19:e3:d7:5b:0e"
    expect(described_class.parse_kernel(k)).to eq(["http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz", "ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/rhel6.2-host.ks.cfg ksdevice=00:19:e3:d7:5b:0e"])
  end

  context "#synchronize_images" do
    before do
      @pxe_server = FactoryBot.create(:pxe_server)
      @pxe_menu   = FactoryBot.create(:pxe_menu_ipxe, :contents => @contents, :pxe_server => @pxe_server)
    end

    it "finds correct number of menu items" do
      @pxe_menu.synchronize_images
      @pxe_menu.save!
      expect(@pxe_menu.pxe_images.length).to eq(3)
      expect(@pxe_menu.pxe_images.all? { |i| i.pxe_server == @pxe_server }).to be_truthy

      @pxe_menu.contents = @contents2
      @pxe_menu.synchronize_images
      @pxe_menu.save!
      expect(@pxe_menu.pxe_images.length).to eq(1)
      expect(@pxe_menu.pxe_images.all? { |i| i.pxe_server == @pxe_server }).to be_truthy
    end
  end
end
