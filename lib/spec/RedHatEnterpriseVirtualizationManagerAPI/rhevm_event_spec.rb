require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. RedHatEnterpriseVirtualizationManagerAPI})))
require 'rhevm_api'

describe RhevmEvent do
  context ".set_event_name" do
    before :each do
      @orig_log, $rhevm_log = $rhevm_log, double("logger")
    end

    after :each do
      $rhevm_log = @orig_log
    end

    it "sets the name corresponding to a valid code" do
      hash = {:code => 1}
      RhevmEvent.send(:set_event_name, hash)
      hash[:name].should eq RhevmEvent::EVENT_CODES[1]
    end

    it "sets 'UNKNOWN' as the name with an invalid code" do
      $rhevm_log.should_receive :warn
      hash = {:code => -1, :description => "Invalid Code"}
      RhevmEvent.send(:set_event_name, hash)
      hash[:name].should eq "UNKNOWN"
    end
  end
end
