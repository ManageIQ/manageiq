require "spec_helper"

describe DialogFieldSortedItem do
  let(:df) { FactoryGirl.build(:dialog_field_sorted_item, :label => 'dialog_field', :name => 'dialog_field') }

  describe "#get_default_value" do
    it "returns the first value when no default and only a single value is available" do
      df.values = [%w(value1 text1)]
      df.get_default_value.should == "value1"
    end

    it "returns nil when no default and multiple values are available" do
      df.values = [%w(value1 text1), %w(value2 text2)]
      df.get_default_value.should be_nil
    end
  end
end
