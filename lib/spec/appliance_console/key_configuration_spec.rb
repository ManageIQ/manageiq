require "spec_helper"
require 'appliance_console/env'
require "appliance_console/key_configuration"

RAILS_ROOT ||= File.expand_path("../../../vmdb", Pathname.new(__FILE__).realpath)

describe ApplianceConsole::KeyConfiguration do
  subject { described_class.new }

  context "#create_key" do
    context "v2_key exists" do
      it "should create the key if forced" do
        File.should_receive(:exist?).and_return(true)
        FileUtils.should_receive(:rm)
        MiqPassword.should_receive(:generate_symmetric)
        subject.create_key(true)
      end

      it "should not create the key if not forced" do
        File.should_receive(:exist?).and_return(true)
        FileUtils.should_not_receive(:rm)
        MiqPassword.should_not_receive(:generate_symmetric)
        subject.create_key(false)
      end
    end

    context "v2_key doesnt exist" do
      it "should create the key if forced" do
        File.should_receive(:exist?).and_return(false)
        FileUtils.should_not_receive(:rm)
        MiqPassword.should_receive(:generate_symmetric)
        subject.create_key(true)
      end

      it "should not create the key if not forced" do
        File.should_receive(:exist?).and_return(false)
        FileUtils.should_not_receive(:rm)
        MiqPassword.should_receive(:generate_symmetric)
        subject.create_key(false)
      end
    end
  end
end
