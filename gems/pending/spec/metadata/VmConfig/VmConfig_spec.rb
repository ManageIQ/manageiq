require "spec_helper"
require 'metadata/VmConfig/VmConfig'

describe VmConfig do
  context "#initialize" do

    it "with a HyperV configuration file encoding in UTF-16" do
      filename = File.join(File.dirname(__FILE__), 'data/hyperv_utf_16.xml')
      config = VmConfig.new(filename)
      config.vendor.should == "microsoft"
    end

  end
end
