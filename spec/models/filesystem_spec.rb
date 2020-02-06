RSpec.describe Filesystem do
  let(:filesystem_conf_file_ascii) do
    <<-EOT
## NB: Unpolished config file
## This config file was taken directly from the upstream repo, and tweaked just enough to work.
## It has not been audited to ensure that everything present is either Heat controlled or a mandatory as-is setting.
## Please submit patches for any setting that should be deleted or Heat-configurable. '"-"'
##  https://git.openstack.org/cgit/openstack/tripleo-image-elements


[DEFAULT]


s3_host=192.0.2.10
ec2_dmz_host=192.0.2.10
ec2_url=http://192.0.2.10:8773/services/Cloud

my_ip=192.0.2.13
    EOT
  end

  let(:filesystem_conf_file_non_ascii) { "abc\u{4242}" }
  let(:filesystem_file_utf16_little_endian) { "\xff\xfe\r\x00\n\x00".force_encoding("ASCII-8BIT") }
  let(:filesystem_file_utf16_big_endian) { "\xfe\xff\x00\r\x00\n".force_encoding("ASCII-8BIT") }

  context "#contents_displayable?" do
    it "filesystem with missing name is not displayable" do
      filesystem = FactoryBot.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_ascii)
      allow(filesystem).to receive(:name).and_return(nil)

      expect(filesystem.contents_displayable?).to be_falsey
    end

    it "filesystem content bigger than 20k characters is not displayable" do
      filesystem = FactoryBot.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_ascii)
      allow(filesystem).to receive(:size).and_return(40_000)

      expect(filesystem.contents_displayable?).to be_falsey
    end

    it "non MIME .conf ascii file is displayable" do
      filesystem = FactoryBot.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_ascii)

      expect(filesystem.contents_displayable?).to be_truthy
    end

    it "non MIME .conf file, with non ascii characters is not displayable" do
      filesystem = FactoryBot.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_non_ascii)
      filesystem.name = "DOES NOT EXIST"

      expect(filesystem.contents_displayable?).to be_falsey
    end

    it "non MIME .conf file, without content is not displayable" do
      filesystem = FactoryBot.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_ascii)
      filesystem.name = "DOES NOT EXIST"
      allow(filesystem).to receive(:has_contents?).and_return(false)

      expect(filesystem.contents_displayable?).to be_falsey
    end

    it "MIME .exe binary file is not displayable" do
      filesystem = FactoryBot.create(:filesystem_binary_file)

      expect(filesystem.contents_displayable?).to be_falsey
    end

    it "MIME .txt non binary file is displayable" do
      filesystem = FactoryBot.create(:filesystem_txt_file)

      expect(filesystem.contents_displayable?).to be_truthy
    end
  end

  context "#displayable_contents" do
    it "returns utf-8 encoded content for utf-16 little endian data" do
      filesystem = FactoryBot.create(:filesystem_txt_file, :contents => filesystem_file_utf16_little_endian)
      expect(filesystem.displayable_contents).to eq("\r\n")
    end

    it "returns utf-8 encoded content for utf-16 big endian data" do
      filesystem = FactoryBot.create(:filesystem_txt_file, :contents => filesystem_file_utf16_big_endian)
      expect(filesystem.displayable_contents).to eq("\r\n")
    end

    it "returns original blob for binary data" do
      filesystem = FactoryBot.create(:filesystem_binary_file)
      expect(filesystem.displayable_contents).to eq(filesystem.contents)
    end
  end
end
