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
    let(:automate_hash) do
      {
        "sort_by"       => "none",
        "sort_order"    => "descending",
        "data_type"     => "datatype",
        "default_value" => "default",
        "required"      => true,
        "values"        => values
      }
    end

    shared_examples_for "DialogFieldSortedItem#normalize_automate_values" do
      before do
        dialog_field.normalize_automate_values(automate_hash)
      end

      it "sets the sort_by" do
        expect(dialog_field.sort_by).to eq(:none)
      end

      it "sets the sort_order" do
        expect(dialog_field.sort_order).to eq(:descending)
      end

      it "sets the data_type" do
        expect(dialog_field.data_type).to eq("datatype")
      end

      it "sets the default_value" do
        expect(dialog_field.default_value).to eq("default")
      end

      it "sets the required" do
        expect(dialog_field.required).to eq(true)
      end
    end

    context "when the automate hash values passed in are blank" do
      let(:values) { nil }

      it_behaves_like "DialogFieldSortedItem#normalize_automate_values"

      it "returns the initial values of the dialog field" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq([["", "<None>"]])
      end
    end

    context "when the automate hash values passed in are not blank" do
      let(:values) { {"lol" => "123"} }

      it_behaves_like "DialogFieldSortedItem#normalize_automate_values"

      it "normalizes the values to an array" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq([%w(lol 123)])
      end
    end
  end
end
