require "spec_helper"

$LOAD_PATH.push(File.expand_path(File.join(File.dirname(__FILE__), %w(.. .. util))))
require 'MiqSshUtilV2'

describe MiqSshUtil do
  context "#temp_cmd_file" do
    before do
      @ssh_util = MiqSshUtil.new("localhost", "temp", "something")
    end

    it "creates a file" do
      count = Dir.glob("/var/tmp/miq-*").size

      @ssh_util.temp_cmd_file("pwd") do |_cmd|
        expect(Dir.glob("/var/tmp/miq-*").size).to eq(count + 1)
      end
    end

    it "writes to file" do
      @ssh_util.temp_cmd_file("pwd") do |cmd|
        expect(File.read(cmd.split(";")[1].strip)).to eq("pwd")
      end
    end

    it "deletes the file" do
      count = Dir.glob("/var/tmp/miq-*").size
      @ssh_util.temp_cmd_file("pwd") {}

      expect(Dir.glob("/var/tmp/miq-*").size).to eq(count)
    end
  end
end
