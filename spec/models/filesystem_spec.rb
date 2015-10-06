require "spec_helper"

describe Filesystem do
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

  context "#contents_displayable?" do
    it "filesystem with missing name is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_ascii)
      filesystem.stub(:name).and_return(nil)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "filesystem content bigger than 20k characters is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_ascii)
      filesystem.stub(:size).and_return(40_000)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "non MIME .conf ascii file is displayable" do
      filesystem = FactoryGirl.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_ascii)

      expect(filesystem.contents_displayable?).to be_true
    end

    it "non MIME .conf file, with non ascii characters is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_non_ascii)
      filesystem.name = "DOES NOT EXIST"

      expect(filesystem.contents_displayable?).to be_false
    end

    it "non MIME .conf file, without content is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_openstack_conf, :contents => filesystem_conf_file_ascii)
      filesystem.name = "DOES NOT EXIST"
      filesystem.stub(:has_contents?).and_return(false)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "MIME .exe binary file is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_binary_file)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "MIME .txt non binary file is displayable" do
      filesystem = FactoryGirl.create(:filesystem_txt_file)

      expect(filesystem.contents_displayable?).to be_true
    end
  end
end
