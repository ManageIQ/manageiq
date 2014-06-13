require "spec_helper"

describe MiqAeDatastore do
  it "should test import database count values" do
    MiqAeClass.count.should eql(54)
    MiqAeField.count.should eql(496)
    MiqAeInstance.count.should eql(222)
    MiqAeNamespace.count.should eql(15)
    MiqAeMethod.count.should eql(174)
    MiqAeValue.count.should eql(1748)
  end
end
