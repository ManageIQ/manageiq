require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util mount})))
require 'miq_generic_mount_session'

describe MiqGenericMountSession do
  context "#connect" do
    before do
      MiqGenericMountSession.stub(:raw_disconnect)
      @s1 = MiqGenericMountSession.new({:uri => '/tmp/abc'})
      @s2 = MiqGenericMountSession.new({:uri => '/tmp/abc'})

      @s1.logger = Logger.new("/dev/null")
      @s2.logger = Logger.new("/dev/null")
    end

    after do
      @s1.disconnect
      @s2.disconnect
    end

    it "is unique" do
      MiqGenericMountSession.should_receive(:base_mount_point).twice.and_return('/tmp')
      @s1.connect
      @s2.connect
    end
  end
end
