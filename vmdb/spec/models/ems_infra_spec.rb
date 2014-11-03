require "spec_helper"

describe EmsInfra do
  it ".types" do
    expected_types = [EmsVmware, EmsRedhat, EmsMicrosoft, EmsKvm].collect { |e| e.ems_type }
    described_class.types.should match_array(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [EmsVmware, EmsMicrosoft, EmsRedhat]
    described_class.supported_subclasses.should match_array(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [EmsVmware, EmsMicrosoft, EmsRedhat].collect { |e| e.ems_type }
    described_class.supported_types.should match_array(expected_types)
  end

end
