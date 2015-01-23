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

  describe "#script_error_values" do
    it "returns the script error values" do
      expect(df.script_error_values).to eq([[nil, "<Script error>"]])
    end
  end

  describe "#normalize_automate_values" do
    let(:dialog_field) { DialogFieldRadioButton.new }

    context "when the values passed in are blank" do
      let(:passed_in_values) { nil }

      it "returns the initial values of the dialog field" do
        expect(dialog_field.normalize_automate_values(passed_in_values)).to eq([["", "<None>"]])
      end
    end

    context "when the values passed in are not blank" do
      let(:passed_in_values) { {"lol" => "123"} }

      it "normalizes the values to an array" do
        expect(dialog_field.normalize_automate_values(passed_in_values)).to eq([%w(lol 123)])
      end
    end
  end
end
