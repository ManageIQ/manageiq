require "spec_helper"

describe PxeServer do
  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)
    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server_not_master, :guid => @guid, :zone => @zone)
    MiqServer.my_server(true)

    @pxe_server = FactoryGirl.create(:pxe_server, :uri_prefix => "nfs", :uri => "nfs:///#{@mnt_point}")
  end

  context "#sync_images_queue" do
    it "should create a queue entry with the correct parameters" do
      msg = @pxe_server.sync_images_queue
      msg.method_name.should == "sync_images"
      msg.priority.should    == 100
      msg.queue_name.should  == "generic"
      msg.class_name.should  == "PxeServer"
    end

    it "should not create a new queue entry when one already exists" do
      @pxe_server.sync_images_queue
      MiqQueue.count.should == 1

      @pxe_server.sync_images_queue
      MiqQueue.count.should == 1
    end
  end

  context "pxelinux depot" do
    before(:each) do
      @pxe_server.pxe_directory = "pxelinux.cfg"
      class << @pxe_server
        def test_mount_point
          @test_mount_point ||= File.join(File.dirname(__FILE__), "pxe_data")
        end

        def test_full_path_to(path)
          File.join(test_mount_point, path)
        end

        def with_depot
          yield
        end

        def file_glob(pattern)
          # Glob the files and return them relative to the test mount point
          Dir.glob(test_full_path_to(pattern)).collect do |f|
            Pathname.new(f).relative_path_from(Pathname.new(test_mount_point)).to_s
          end
        end

        def file_read(file)
          File.read(test_full_path_to(file))
        end

        def file_file?(file)
          File.file?(test_full_path_to(file))
        end

        def file_open(*args, &block)
          fname = test_full_path_to(args.shift)
          File.open(fname, *args, &block)
        end

        def file_write(file, contents)
          fname = test_full_path_to(file)
          FileUtils.mkdir_p(File.dirname(fname))
          File.open(fname, "w") { |fd| fd.write(contents) }
        end
      end
    end

    context "#sync_images" do
      before(:each) do
        @expected = [
          ["default",              "Ubuntu-10.10-Desktop-amd64-LIVE_BOOT", "ubuntu-10.10-desktop-amd64/vmlinuz"],
          ["default",              "Ubuntu-10.10-Desktop-i386-LIVE_BOOT",  "ubuntu-10.10-desktop-i386/vmlinuz"],
          ["default",              "VMware ESXi 4.1-260247",               "VMware-VMvisor-Installer-4.1.0-260247/mboot.c32"],
          ["default",              "gPXE",                                 "gpxe/undionly.0"],
          ["default",              "iPXE",                                 "ipxe/undionly.0"],
          ["C0A8FDC7",             "ubuntu-10.10-desktop-amd64",           "ubuntu-10.10-desktop-amd64/vmlinuz"],
          ["01-00-0c-29-f3-1f-12", "Ubuntu-10.10-Desktop-i386-LIVE_BOOT",  "ubuntu-10.10-desktop-i386/vmlinuz"]
        ]
      end

      it "without existing data" do
        @pxe_server.sync_images
        @pxe_server.pxe_images.collect { |i| [i.path, i.name, i.kernel] }.should match_array @expected
      end

      it "with existing data" do
        @pxe_server.pxe_images = [
          FactoryGirl.create(:pxe_image_pxelinux, :path => "XXX",     :name => "XXX"),
          FactoryGirl.create(:pxe_image_pxelinux, :path => "default", :name => "XXX"),
          FactoryGirl.create(:pxe_image_pxelinux, :path => "default", :name => "iPXE", :kernel => "XXX"),
        ]

        @pxe_server.sync_images
        @pxe_server.pxe_images.collect { |i| [i.path, i.name, i.kernel] }.should match_array @expected
      end
    end

    context "#create_provisioning_files" do
      it "without kickstart" do
        @pxe_server.sync_images
        expected_name = @pxe_server.test_full_path_to("#{@pxe_server.pxe_directory}/01-00-19-e3-d7-5b-0e")
        expected_contents = <<-PXE
timeout 0
default Ubuntu-10.10-Desktop-i386-LIVE_BOOT

label Ubuntu-10.10-Desktop-i386-LIVE_BOOT
   menu label Ubuntu-10.10-Desktop-i386-LIVE_BOOT
   kernel ubuntu-10.10-desktop-i386/vmlinuz
   append initrd=ubuntu-10.10-desktop-i386/initrd.lz vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/nfsboot/ubuntu-10.10-desktop-i386 -- quiet

PXE
        image = @pxe_server.pxe_images.find_by_name("Ubuntu-10.10-Desktop-i386-LIVE_BOOT")
        begin
          @pxe_server.create_provisioning_files(image, "00:19:e3:d7:5b:0e")
          File.exist?(expected_name).should be_true

          File.read(expected_name).should == expected_contents
        ensure
          File.delete(expected_name) if File.exist?(expected_name)
        end
      end

      it "with kickstart" do
        @pxe_server.customization_directory = @pxe_server.pxe_directory
        @pxe_server.access_url = "http://example.com"
        @pxe_server.sync_images
        dashed_mac_address = "01-00-19-e3-d7-5b-0e"
        expected_name = @pxe_server.test_full_path_to("#{@pxe_server.pxe_directory}/#{dashed_mac_address}")
        expected_ks_name = "#{expected_name}.ks.cfg"

        image = @pxe_server.pxe_images.find_by_name("Ubuntu-10.10-Desktop-i386-LIVE_BOOT")

        ks_contents = "FOO"
        kickstart = FactoryGirl.create(:customization_template_kickstart, :script => ks_contents)

        expected_contents = <<-PXE
timeout 0
default Ubuntu-10.10-Desktop-i386-LIVE_BOOT

label Ubuntu-10.10-Desktop-i386-LIVE_BOOT
   menu label Ubuntu-10.10-Desktop-i386-LIVE_BOOT
   kernel ubuntu-10.10-desktop-i386/vmlinuz
   append initrd=ubuntu-10.10-desktop-i386/initrd.lz vga=normal boot=casper netboot=nfs nfsroot=192.168.252.60:/srv/nfsboot/ubuntu-10.10-desktop-i386 -- quiet ks=#{@pxe_server.access_url}/#{@pxe_server.customization_directory}/#{dashed_mac_address}.ks.cfg ksdevice=00:19:e3:d7:5b:0e

PXE

        begin
          @pxe_server.create_provisioning_files(image, "00:19:e3:d7:5b:0e", nil, kickstart)
          File.exist?(expected_name).should be_true
          File.read(expected_name).should == expected_contents

          File.exist?(expected_ks_name).should be_true
          File.read(expected_ks_name).should == ks_contents
        ensure
          File.delete(expected_name) if File.exist?(expected_name)
          File.delete(expected_ks_name) if File.exist?(expected_ks_name)
        end
      end

    end
  end

  context "ipxe depot" do
    before(:each) do
      @pxe_server.pxe_directory = "ipxe/mac"
      class << @pxe_server
        def test_mount_point
          @test_mount_point ||= File.join(File.dirname(__FILE__), "pxe_data")
        end

        def test_full_path_to(path)
          File.join(test_mount_point, path)
        end

        def with_depot
          yield
        end

        def file_glob(pattern)
          # Glob the files and return them relative to the test mount point
          Dir.glob(test_full_path_to(pattern)).collect do |f|
            Pathname.new(f).relative_path_from(Pathname.new(test_mount_point)).to_s
          end
        end

        def file_read(file)
          File.read(test_full_path_to(file))
        end

        def file_file?(file)
          File.file?(test_full_path_to(file))
        end

        def file_open(*args, &block)
          fname = test_full_path_to(args.shift)
          File.open(fname, *args, &block)
        end

        def file_write(file, contents)
          fname = test_full_path_to(file)
          FileUtils.mkdir_p(File.dirname(fname))
          File.open(fname, "w") { |fd| fd.write(contents) }
        end
      end
    end

    context "#sync_images" do
      before(:each) do
        @expected = [
          ["00-50-56-91-79-d5", "00-50-56-91-79-d5", "http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz", "ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/rhel6.2-host.ks.cfg ksdevice=00:50:56:91:79:d5"]
        ]
      end

      it "without existing images" do
        @pxe_server.sync_images
        @pxe_server.pxe_images.collect { |i| [i.path, i.name, i.kernel, i.kernel_options] }.should match_array @expected
      end

      it "with existing images" do
        @pxe_server.pxe_images = [
          FactoryGirl.create(:pxe_image_ipxe, :path => "XXX",               :name => "XXX"),
          FactoryGirl.create(:pxe_image_ipxe, :path => "00-50-56-91-79-d5", :name => "XXX"),
          FactoryGirl.create(:pxe_image_ipxe, :path => "00-50-56-91-79-d5", :name => "00-50-56-91-79-d5", :kernel => "XXX")
        ]

        @pxe_server.sync_images
        @pxe_server.pxe_images.collect { |i| [i.path, i.name, i.kernel, i.kernel_options] }.should match_array @expected
      end
    end

    context "#create_provisioning_files" do
      it "without kickstart" do
        image = FactoryGirl.create(:pxe_image_ipxe,
          :pxe_server     => @pxe_server,
          :kernel         => "http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz",
          :kernel_options => "ramdisk_size=10000 ksdevice=00:50:56:91:79:d5",
          :initrd         => "http://192.168.252.60/ipxe/rhel6.2-desktop/initrd.img"
        )
        expected_name = @pxe_server.test_full_path_to("#{@pxe_server.pxe_directory}/00-19-e3-d7-5b-0e")
        expected_contents = <<-PXE
#!ipxe
kernel #{image.kernel} ramdisk_size=10000
initrd #{image.initrd}
boot
PXE
        begin
          @pxe_server.create_provisioning_files(image, "00:19:e3:d7:5b:0e")
          File.exist?(expected_name).should be_true

          File.read(expected_name).should == expected_contents
        ensure
          File.delete(expected_name) if File.exist?(expected_name)
        end
      end

      it "with kickstart" do
        @pxe_server.customization_directory = @pxe_server.pxe_directory
        @pxe_server.access_url = "http://example.com"
        dashed_mac_address = "00-19-e3-d7-5b-0e"
        expected_name = @pxe_server.test_full_path_to("#{@pxe_server.pxe_directory}/#{dashed_mac_address}")
        expected_ks_name = "#{expected_name}.ks.cfg"

        image = FactoryGirl.create(:pxe_image_ipxe,
          :pxe_server     => @pxe_server,
          :kernel         => "http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz",
          :kernel_options => "ramdisk_size=10000 ksdevice=00:50:56:91:79:d5",
          :initrd         => "http://192.168.252.60/ipxe/rhel6.2-desktop/initrd.img"
        )

        ks_contents = "FOO"
        kickstart = FactoryGirl.create(:customization_template_kickstart, :script => ks_contents)

        expected_contents = <<-PXE
#!ipxe
kernel #{image.kernel} ramdisk_size=10000 ksdevice=00:19:e3:d7:5b:0e ks=#{@pxe_server.access_url}/#{@pxe_server.customization_directory}/#{dashed_mac_address}.ks.cfg
initrd #{image.initrd}
boot
PXE
        begin
          @pxe_server.create_provisioning_files(image, "00:19:e3:d7:5b:0e", nil, kickstart)
          File.exist?(expected_name).should be_true
          File.read(expected_name).should == expected_contents

          File.exist?(expected_ks_name).should be_true
          File.read(expected_ks_name).should == ks_contents
        ensure
          File.delete(expected_name) if File.exist?(expected_name)
          File.delete(expected_ks_name) if File.exist?(expected_ks_name)
        end
      end
    end
  end

  context "with pxe images" do
    before(:each) do
      pxe_menu          = FactoryGirl.create(:pxe_menu,  :pxe_server => @pxe_server)
      @advertised_image = FactoryGirl.create(:pxe_image, :pxe_server => @pxe_server, :pxe_menu => pxe_menu)
      @discovered_image = FactoryGirl.create(:pxe_image, :pxe_server => @pxe_server)
    end

    it "#pxe_images" do
      @pxe_server.pxe_images.should  match_array([@advertised_image, @discovered_image])
    end

    it "#advertised_pxe_images" do
      @pxe_server.advertised_pxe_images.should == [@advertised_image]
    end

    it "#discovered_pxe_images" do
      @pxe_server.discovered_pxe_images.should == [@discovered_image]
    end
  end
end
