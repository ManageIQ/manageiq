require "spec_helper"

describe EmsKvm do
  it ".ems_type" do
    described_class.ems_type.should == 'kvm'
  end

  it ".description" do
    described_class.description.should == 'KVM'
  end

end
