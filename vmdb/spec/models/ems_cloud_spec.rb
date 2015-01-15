require "spec_helper"

describe EmsCloud do
  it ".types" do
    expected_types = [EmsAmazon, EmsOpenstack].collect(&:ems_type)
    described_class.types.should match_array(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [EmsAmazon, EmsOpenstack]
    described_class.supported_subclasses.should match_array(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [EmsAmazon, EmsOpenstack].collect(&:ems_type)
    described_class.supported_types.should match_array(expected_types)
  end

end
