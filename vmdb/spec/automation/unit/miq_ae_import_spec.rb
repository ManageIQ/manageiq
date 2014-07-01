require "spec_helper"

describe MiqAeDatastore do
  it "should test import database count values" do
    MiqAeClass.count.should eql(53)
    MiqAeField.count.should eql(479)
    MiqAeInstance.count.should eql(222)
    MiqAeNamespace.count.should eql(14)
    MiqAeMethod.count.should eql(169)
    MiqAeValue.count.should eql(1748)
  end
end
