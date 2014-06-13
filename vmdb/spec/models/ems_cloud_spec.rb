require "spec_helper"

describe EmsCloud do
  it ".types" do
    expected_types = [EmsAmazon, EmsOpenstack].collect { |e| e.ems_type }
    described_class.types.should have_same_elements(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [EmsAmazon, EmsOpenstack]
    described_class.supported_subclasses.should have_same_elements(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [EmsAmazon, EmsOpenstack].collect { |e| e.ems_type }
    described_class.supported_types.should have_same_elements(expected_types)
  end

end
