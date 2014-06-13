require "spec_helper"

describe EmsMicrosoft do
  it ".ems_type" do
    described_class.ems_type.should == 'scvmm'
  end

  it ".description" do
    described_class.description.should == 'Microsoft System Center VMM'
  end

end
