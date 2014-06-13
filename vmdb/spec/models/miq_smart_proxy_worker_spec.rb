require "spec_helper"

describe MiqSmartProxyWorker do
  context ".build_command_line" do
    before do
      @guid = MiqUUID.new_guid
      ruby_path = File.join(RbConfig::CONFIG["bindir"], "ruby")
      rails_path = Rails.root.join("bin", "rails")
      @base_cmd_line = "nice -n +10 #{ruby_path} #{rails_path} runner #{Rails.root.join("lib", "workers", "bin", "worker.rb")} smart_proxy_worker MiqSmartProxyWorker --guid \"#{@guid}\""
    end

    it "is appliance" do
      expected_cmd_line = "LD_LIBRARY_PATH=\"${LD_LIBRARY_PATH}:#{Rails.root.join("..", "lib", "VixDiskLib", "vddklib")}\" #{@base_cmd_line}"

      MiqEnvironment::Command.should_receive(:is_appliance?).twice.and_return(true)

      expect(described_class.build_command_line(:guid => @guid)).to eq(expected_cmd_line)
    end

    it "is not appliance" do
      MiqEnvironment::Command.should_receive(:is_appliance?).twice.and_return(false)

      expect(described_class.build_command_line(:guid => @guid)).to eq(@base_cmd_line)
    end
  end
end
