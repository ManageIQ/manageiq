require "spec_helper"
require 'util/mount/miq_generic_mount_session'

describe MiqGenericMountSession do
  context "#connect" do
    before do
      MiqGenericMountSession.stub(:raw_disconnect)
      @s1 = MiqGenericMountSession.new(:uri => '/tmp/abc', :mount_point => 'tmp')
      @s2 = MiqGenericMountSession.new(:uri => '/tmp/abc', :mount_point => 'tmp')

      @s1.logger = Logger.new("/dev/null")
      @s2.logger = Logger.new("/dev/null")
    end

    after do
      @s1.disconnect
      @s2.disconnect
    end

    it "is unique" do
      @s1.connect
      @s2.connect

      expect(@s1.mnt_point).to_not eq(@s2.mnt_point)
    end
  end
end
