require "spec_helper"

require "appliance_console/logging"

describe ApplianceConsole::Logging do
  before do
    described_class.instance_variable_set(:@logger, nil)
    described_class.instance_variable_set(:@default_logger, nil)
  end

  it ".logger=" do
    described_class.logger = double(:info => true)
    described_class.logger.info.should == true
  end

  it ".logger uses default_logger" do
    described_class.logger.should == described_class.default_logger
  end

  it ".default_logger" do
    l = described_class.default_logger
    l.should be_instance_of Logger
    l.level.should == 1
  end

end
