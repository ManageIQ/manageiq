RSpec.describe PxeServer do
  before do
    EvmSpecHelper.local_miq_server
    @pxe_server = FactoryBot.create(:pxe_server)
  end

  subject { FactoryBot.create(:pxe_server) }

  context "#sync_images_queue" do
    it "should create a queue entry with the correct parameters" do
      msg = @pxe_server.sync_images_queue
      expect(msg.method_name).to eq("sync_images")
      expect(msg.priority).to eq(100)
      expect(msg.queue_name).to eq("generic")
      expect(msg.class_name).to eq("PxeServer")
    end

    it "should not create a new queue entry when one already exists" do
      @pxe_server.sync_images_queue
      expect(MiqQueue.count).to eq(1)

      @pxe_server.sync_images_queue
      expect(MiqQueue.count).to eq(1)
    end
  end

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:pxe_server)
    expect { m.valid? }.not_to make_database_queries
  end

  context "pxelinux depot" do
    before do
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
      before do
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
        expect(@pxe_server.pxe_images.collect { |i| [i.path, i.name, i.kernel] }).to match_array @expected
      end

      it "with existing data" do
        @pxe_server.pxe_images = [
          FactoryBot.create(:pxe_image_pxelinux),
          FactoryBot.create(:pxe_image_pxelinux),
          FactoryBot.create(:pxe_image_pxelinux),
        ]

        @pxe_server.sync_images
        expect(@pxe_server.pxe_images.collect { |i| [i.path, i.name, i.kernel] }).to match_array @expected
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
        image = @pxe_server.pxe_images.find_by(:name => "Ubuntu-10.10-Desktop-i386-LIVE_BOOT")
        begin
          @pxe_server.create_provisioning_files(image, "00:19:e3:d7:5b:0e")
          expect(File.exist?(expected_name)).to be_truthy

          expect(File.read(expected_name)).to eq(expected_contents)
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

        image = @pxe_server.pxe_images.find_by(:name => "Ubuntu-10.10-Desktop-i386-LIVE_BOOT")

        ks_contents = "FOO"
        kickstart = FactoryBot.create(:customization_template_kickstart, :script => ks_contents)

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
          expect(File.exist?(expected_name)).to be_truthy
          expect(File.read(expected_name)).to eq(expected_contents)

          expect(File.exist?(expected_ks_name)).to be_truthy
          expect(File.read(expected_ks_name)).to eq(ks_contents)
        ensure
          File.delete(expected_name) if File.exist?(expected_name)
          File.delete(expected_ks_name) if File.exist?(expected_ks_name)
        end
      end
    end
  end

  context "ipxe depot" do
    before do
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
      before do
        @expected = [
          ["00-50-56-91-79-d5", "00-50-56-91-79-d5", "http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz", "ramdisk_size=10000 ks=http://192.168.252.60/pxelinux.cfg/rhel6.2-host.ks.cfg ksdevice=00:50:56:91:79:d5"]
        ]
      end

      it "without existing images" do
        @pxe_server.sync_images
        expect(@pxe_server.pxe_images.collect { |i| [i.path, i.name, i.kernel, i.kernel_options] }).to match_array @expected
      end

      it "with existing images" do
        @pxe_server.pxe_images = [
          FactoryBot.create(:pxe_image_ipxe),
          FactoryBot.create(:pxe_image_ipxe, :path => "00-50-56-91-79-d5"),
          FactoryBot.create(:pxe_image_ipxe, :path => "00-50-56-91-79-d5")
        ]

        @pxe_server.sync_images
        expect(@pxe_server.pxe_images.collect { |i| [i.path, i.name, i.kernel, i.kernel_options] }).to match_array @expected
      end
    end

    context "#create_provisioning_files" do
      it "without kickstart" do
        image = FactoryBot.create(:pxe_image_ipxe,
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
          expect(File.exist?(expected_name)).to be_truthy

          expect(File.read(expected_name)).to eq(expected_contents)
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

        image = FactoryBot.create(:pxe_image_ipxe,
                                   :pxe_server     => @pxe_server,
                                   :kernel         => "http://192.168.252.60/ipxe/rhel6.2-desktop/vmlinuz",
                                   :kernel_options => "ramdisk_size=10000 ksdevice=00:50:56:91:79:d5",
                                   :initrd         => "http://192.168.252.60/ipxe/rhel6.2-desktop/initrd.img"
                                  )

        ks_contents = "FOO"
        kickstart = FactoryBot.create(:customization_template_kickstart, :script => ks_contents)

        expected_contents = <<-PXE
#!ipxe
kernel #{image.kernel} ramdisk_size=10000 ksdevice=00:19:e3:d7:5b:0e ks=#{@pxe_server.access_url}/#{@pxe_server.customization_directory}/#{dashed_mac_address}.ks.cfg
initrd #{image.initrd}
boot
PXE
        begin
          @pxe_server.create_provisioning_files(image, "00:19:e3:d7:5b:0e", nil, kickstart)
          expect(File.exist?(expected_name)).to be_truthy
          expect(File.read(expected_name)).to eq(expected_contents)

          expect(File.exist?(expected_ks_name)).to be_truthy
          expect(File.read(expected_ks_name)).to eq(ks_contents)
        ensure
          File.delete(expected_name) if File.exist?(expected_name)
          File.delete(expected_ks_name) if File.exist?(expected_ks_name)
        end
      end
    end
  end

  context "with pxe images" do
    before do
      pxe_menu          = FactoryBot.create(:pxe_menu,  :pxe_server => @pxe_server)
      @advertised_image = FactoryBot.create(:pxe_image, :pxe_server => @pxe_server, :pxe_menu => pxe_menu)
      @discovered_image = FactoryBot.create(:pxe_image, :pxe_server => @pxe_server)
    end

    it "#pxe_images" do
      expect(@pxe_server.pxe_images).to  match_array([@advertised_image, @discovered_image])
    end

    it "#advertised_pxe_images" do
      expect(@pxe_server.advertised_pxe_images).to eq([@advertised_image])
    end

    it "#discovered_pxe_images" do
      expect(@pxe_server.discovered_pxe_images).to eq([@discovered_image])
    end
  end

  describe '#ensure_menu_list' do
    context 'when creating server' do
      subject { FactoryBot.build(:pxe_server) }
      it 'existing menus remain' do
        subject.ensure_menu_list(%w[new])
        subject.save!
        expect(PxeMenu.count).to eq(1)
        expect(subject.pxe_menus.count).to eq(1)
      end
    end

    context 'when updating server' do
      let!(:pxe_menu_1)  { FactoryBot.create(:pxe_menu, :pxe_server => subject, :file_name => 'existing1') }
      let!(:pxe_image_1) { FactoryBot.create(:pxe_image, :pxe_server => subject, :pxe_menu => pxe_menu_1) }
      let!(:pxe_menu_2)  { FactoryBot.create(:pxe_menu, :pxe_server => subject, :file_name => 'existing2') }
      let!(:pxe_image_2) { FactoryBot.create(:pxe_image, :pxe_server => subject, :pxe_menu => pxe_menu_2) }

      context 'when nothing changed' do
        let(:menus) { %w[existing1 existing2] }
        it 'all menus remain' do
          subject.ensure_menu_list(menus)
          expect(PxeMenu.count).to eq(2)
          expect(PxeImage.count).to eq(2)
          expect(subject.pxe_menus.find_by(:id => pxe_menu_1.id)).to eq(pxe_menu_1)
          expect(subject.pxe_menus.find_by(:id => pxe_menu_2.id)).to eq(pxe_menu_2)
        end
      end

      context 'when new menus are added' do
        let(:menus) { %w[existing1 existing2 new] }
        it 'existing menus remain' do
          subject.ensure_menu_list(menus)
          expect(PxeMenu.count).to eq(3)
          expect(PxeImage.count).to eq(2)
          expect(subject.pxe_menus.find_by(:id => pxe_menu_1.id)).to eq(pxe_menu_1)
          expect(subject.pxe_menus.find_by(:id => pxe_menu_2.id)).to eq(pxe_menu_2)
          expect(subject.pxe_menus.find_by(:file_name => 'new')).not_to be_nil
        end
      end

      context 'when menus are deleted' do
        let(:menus) { %w[existing1] }
        it 'menus are destroyed' do
          subject.ensure_menu_list(menus)
          expect(PxeMenu.count).to eq(1)
          expect(PxeImage.count).to eq(1)
          expect(subject.pxe_menus.find_by(:id => pxe_menu_1.id)).to eq(pxe_menu_1)
          expect(subject.pxe_menus.find_by(:id => pxe_menu_2.id)).to be_nil
        end
      end

      context 'when different menus are specified' do
        let(:menus) { %w[new] }
        it 'old menus are destroyed' do
          subject.ensure_menu_list(menus)
          expect(PxeMenu.count).to eq(1)
          expect(PxeImage.count).to eq(0)
          expect(subject.pxe_menus.find_by(:file_name => 'new')).not_to be_nil
        end
      end
    end

    context 'when two servers have similar menu' do
      let(:other_server) { FactoryBot.create(:pxe_server) }
      it 'they are not mixed up' do
        subject.ensure_menu_list(%w[new])
        other_server.ensure_menu_list(%w[new])
        expect(PxeMenu.count).to eq(2)
        expect(subject.pxe_menus.count).to eq(1)
        expect(other_server.pxe_menus.count).to eq(1)
        expect(subject.pxe_menus.map(&:id)).not_to eq(other_server.pxe_menus.map(&:id))
      end
    end
  end
end
