RSpec.describe PxeMenuPxelinux do
  before do
    @contents = <<-PXEMENU
default vesamenu.c32
Menu Title ManageIQ TFTP Boot Menu

label iPXE
 menu default
 menu label iPXE Boot
 kernel ipxe/undionly.0

label VMware ESXi 4.1-260247
  menu label VMware ESXi 4.1-260247
  kernel VMware-VMvisor-Installer-4.1.0-260247/mboot.c32
  append VMware-VMvisor-Installer-4.1.0-260247/vmkboot.gz ks=http://192.168.252.60/ks.cfg --- VMware-VMvisor-Installer-4.1.0-260247/vmkernel.gz --- VMware-VMvisor-Installer-4.1.0-260247/sys.vgz --- VMware-VMvisor-Installer-4.1.0-260247/cim.vgz --- VMware-VMvisor-Installer-4.1.0-260247/ienviron.vgz --- VMware-VMvisor-Installer-4.1.0-260247/install.vgz

label Ubuntu-10.10-Desktop-i386-LIVE_BOOT
  menu label Ubuntu-10.10-Desktop-i386-LIVE_BOOT
  kernel ubuntu-10.10-desktop-i386/vmlinuz
  append vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/nfsboot/ubuntu-10.10-desktop-i386 initrd=ubuntu-10.10-desktop-i386/initrd.lz -- quiet

label Ubuntu-10.10-Desktop-amd64-LIVE_BOOT
  menu label Ubuntu-10.10-Desktop-amd64-LIVE_BOOT
  kernel ubuntu-10.10-desktop-amd64/vmlinuz
  append vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/nfsboot/ubuntu-10.10-desktop-amd64 initrd=ubuntu-10.10-desktop-amd64/initrd.lz -- quiet

label Ubuntu-11.04-Server-amd64
  menu label Ubuntu-11.04-Server-amd64
  kernel ubuntu-11.04-server-amd64/linux
  append vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/nfsboot/ubuntu-11.04-server-amd64 initrd=ubuntu-11.04-server-amd64/initrd.gz -- quiet

label RHEL6
  menu label RHEL6
  kernel rhel6/vmlinuz
  append initrd=rhel6/initrd.img ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/01-78-2b-cb-00-f6-6c.ks.cfg ksdevice=78:2b:cb:00:f6:6c

label RHEL6.2-Desktop
  menu label RHEL6.2-Desktop
  kernel rhel6.2-desktop/vmlinuz
  append initrd=rhel6.2-desktop/initrd.img ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/rhel6.2-desktop.ks.cfg ksdevice=78:2b:cb:00:f6:6c

label VMware ESXi 5.0.0-381646
  menu label VMware ESXi 5.0.0-381646
  kernel VMware-VMvisor-Installer-5.0.0-381646.x86_64/mboot.c32
  append -c VMware-VMvisor-Installer-5.0.0-381646.x86_64/boot.cfg

label VMware ESXi 5.0.0-469512
  menu label VMware ESXi 5.0.0-469512
  kernel VMware-VMvisor-Installer-5.0.0-469512.x86_64/mboot.c32
  append -c VMware-VMvisor-Installer-5.0.0-469512.x86_64/boot.cfg

label VMware ESXi 5.0.0-504890
  menu label VMware ESXi 5.0.0-504890
  kernel VMware-VMvisor-Installer-5.0.0-504890.x86_64/mboot.c32
  append -c VMware-VMvisor-Installer-5.0.0-504890.x86_64/boot.cfg

label Local_drive
  localboot 0
  menu label Local Drive

prompt 0
timeout 600
PXEMENU

    @contents2 = <<-PXEMENU
default vesamenu.c32
Menu Title ManageIQ TFTP Boot Menu

label RHEL6
  menu label RHEL6
  kernel rhel6/vmlinuz
  append initrd=rhel6/initrd.img ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/01-78-2b-cb-00-f6-6c.ks.cfg ksdevice=78:2b:cb:00:f6:6c

prompt 0
timeout 600
PXEMENU
  end

  it ".parse_contents" do
    expect(described_class.parse_contents(@contents).length).to eq(10)
    expect(described_class.parse_contents(@contents).all? { |h| h.kind_of?(Hash) }).to be_truthy
  end

  it ".parse_append" do
    a = "initrd=rhel6/initrd.img ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/01-78-2b-cb-00-f6-6c.ks.cfg ksdevice=78:2b:cb:00:f6:6c"
    expect(described_class.parse_append(a)).to eq(["ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/01-78-2b-cb-00-f6-6c.ks.cfg ksdevice=78:2b:cb:00:f6:6c", "rhel6/initrd.img"])
  end

  context "#synchronize_images" do
    before do
      @pxe_server = FactoryBot.create(:pxe_server)
      @pxe_menu = FactoryBot.create(:pxe_menu_pxelinux, :contents => @contents, :pxe_server => @pxe_server)
    end

    it "finds correct number of menu items" do
      @pxe_menu.synchronize_images
      @pxe_menu.save!
      expect(@pxe_menu.pxe_images.length).to eq(10)
      expect(@pxe_menu.pxe_images.all? { |i| i.pxe_server == @pxe_server }).to be_truthy

      @pxe_menu.contents = @contents2
      @pxe_menu.synchronize_images
      @pxe_menu.save!
      expect(@pxe_menu.pxe_images.length).to eq(1)
      expect(@pxe_menu.pxe_images.all? { |i| i.pxe_server == @pxe_server }).to be_truthy
    end
  end
end
