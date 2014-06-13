require "spec_helper"

describe EmsRedhat do
  it ".ems_type" do
    described_class.ems_type.should == 'rhevm'
  end

  it ".description" do
    described_class.description.should == 'Red Hat Enterprise Virtualization Manager'
  end

end
