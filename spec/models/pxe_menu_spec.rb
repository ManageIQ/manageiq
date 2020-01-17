RSpec.describe PxeMenu do
  before do
    @contents_pxelinux = <<-PXEMENU
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

    @contents_ipxe = <<-PXEMENU
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
  end

  it ".class_from_contents" do
    expect(described_class.class_from_contents(@contents_pxelinux)).to eq(PxeMenuPxelinux)
    expect(described_class.class_from_contents(@contents_ipxe)).to eq(PxeMenuIpxe)
  end

  context "#synchronize" do
    before do
      @pxe_server = FactoryBot.create(:pxe_server)
    end

    context "ipxe" do
      before { allow(@pxe_server).to receive_messages(:read_file => @contents_ipxe) }

      it "on typed menu" do
        pxe_menu = FactoryBot.create(:pxe_menu_ipxe, :pxe_server => @pxe_server)
        pxe_menu.synchronize

        new_pxe_menu = PxeMenu.find(pxe_menu.id)
        expect(new_pxe_menu).to be_kind_of(PxeMenuIpxe)
        expect(new_pxe_menu.pxe_images.length).to eq(3)
        expect(new_pxe_menu.pxe_images.first.type).to eq('PxeImageIpxe')
      end

      it "on untyped menu" do
        pxe_menu = FactoryBot.create(:pxe_menu, :pxe_server => @pxe_server)
        pxe_menu.synchronize

        new_pxe_menu = PxeMenu.find(pxe_menu.id)
        expect(new_pxe_menu).to be_kind_of(PxeMenuIpxe)
        expect(new_pxe_menu.pxe_images.length).to eq(3)
      end

      it "on typed menu switching to a different type" do
        pxe_menu = FactoryBot.create(:pxe_menu_pxelinux, :contents => @contents_pxelinux, :pxe_server => @pxe_server)
        pxe_menu.synchronize

        new_pxe_menu = PxeMenu.find(pxe_menu.id)
        expect(new_pxe_menu).to be_kind_of(PxeMenuIpxe)
        expect(new_pxe_menu.pxe_images.length).to eq(3)
      end
    end

    context "pxelinux" do
      before { allow(@pxe_server).to receive_messages(:read_file => @contents_pxelinux) }

      it "on typed menu" do
        pxe_menu = FactoryBot.create(:pxe_menu_pxelinux, :pxe_server => @pxe_server)
        pxe_menu.synchronize

        new_pxe_menu = PxeMenu.find(pxe_menu.id)
        expect(new_pxe_menu).to be_kind_of(PxeMenuPxelinux)
        expect(new_pxe_menu.pxe_images.length).to eq(10)
        expect(new_pxe_menu.pxe_images.first.type).to eq('PxeImagePxelinux')
      end
    end
  end

  describe 'destroy' do
    let!(:pxe_image) { FactoryBot.create(:pxe_image, :pxe_menu => subject) }

    it 'removes related pxe images as well' do
      expect(PxeMenu.count).to eq(1)
      expect(PxeImage.count).to eq(1)
      subject.destroy
      expect(PxeMenu.count).to eq(0)
      expect(PxeImage.count).to eq(0)
    end
  end
end
