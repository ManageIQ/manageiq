require "spec_helper"
require 'util/miq-iecunits'

describe MiqIECUnits do
  context "#string_to_value" do
    it "convert IEC bytes size to integer value" do
      SIZES = [
        ["0",    0],
        ["1",    1],
        ["10",   10],
        ["1Ki",  1_024],
        ["7Ki",  7_168],
        ["10Ki", 10_240],
        ["1Mi",  1_048_576],
        ["3Mi",  3_145_728],
        ["10Mi", 10_485_760],
        ["1Gi",  1_073_741_824],
        ["1Ti",  1_099_511_627_776]
      ]

      SIZES.each do |x, y|
        MiqIECUnits.string_to_value(x).should == y
      end
    end
  end
end
