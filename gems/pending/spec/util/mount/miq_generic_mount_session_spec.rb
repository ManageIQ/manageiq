require "spec_helper"
require "util/mount/miq_generic_mount_session"

describe MiqGenericMountSession do
  it "#connect returns a string pointing to the mount point" do
    allow(described_class).to receive(:raw_disconnect)
    s = described_class.new(:uri => '/tmp/abc')
    s.logger = Logger.new("/dev/null")

    result = s.connect
    expect(result).to     be_kind_of(String)
    expect(result).to_not be_blank

    s.disconnect
  end

  it "#mount_share is unique" do
    expect(described_class.new(:uri => '/tmp/abc').mount_share).to_not eq(described_class.new(:uri => '/tmp/abc').mount_share)
  end
end
