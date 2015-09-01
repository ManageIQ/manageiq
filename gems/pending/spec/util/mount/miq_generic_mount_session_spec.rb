require "spec_helper"
require 'util/mount/miq_generic_mount_session'

describe MiqGenericMountSession do
  it "#connect returns a string pointing to the mount point" do
    described_class.stub(:raw_disconnect)
    s = described_class.new(:uri => '/tmp/abc')
    s.logger = Logger.new("/dev/null")

    expect(s.connect).to match(/\A\/tmp\/miq_\d{8}-\d{5}-\w+\z/)

    s.disconnect
  end

  context "#mount_share" do
    it "without :mount_point uses default temp directory as a base" do
      expect(described_class.new(:uri => '/tmp/abc').mount_share).to match(/\A\/tmp\/miq_\d{8}-\d{5}-\w+\z/)
    end

    it "with :mount_point uses specified directory as a base" do
      expect(described_class.new(:uri => '/tmp/abc', :mount_point => "abc").mount_share).to match(/\Aabc\/miq_\d{8}-\d{5}-\w+\z/)
    end

    it "is unique" do
      expect(described_class.new(:uri => '/tmp/abc').mount_share).to_not eq(described_class.new(:uri => '/tmp/abc').mount_share)
    end
  end
end
