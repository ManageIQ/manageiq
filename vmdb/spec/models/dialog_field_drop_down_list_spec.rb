require "spec_helper"

describe DialogFieldDropDownList do
  context "dialog_field_drop_down_list" do
    before(:each) do
      @df = FactoryGirl.create(:dialog_field_sorted_item, :label => 'drop_down_list', :name => 'drop_down_list')
    end

    it "sort_by" do
      @df.sort_by.should == :description
      @df.sort_by = :none
      @df.sort_by.should == :none
      @df.sort_by = :value
      @df.sort_by.should == :value
      lambda { @df.sort_by = :data }.should raise_error(RuntimeError)
      @df.sort_by.should == :value
    end

    it "sort_order" do
      @df.sort_order.should == :ascending
      @df.sort_order = :descending
      @df.sort_order.should == :descending
      lambda { @df.sort_order = :mixed }.should raise_error(RuntimeError)
      @df.sort_order.should == :descending
    end

    it "return sorted values array as strings" do
      @df.data_type = "string"
      @df.values = [["2", "Y"], ["1", "Z"], ["3", "X"]]
      @df.values.should == [["3", "X"], ["2", "Y"], ["1", "Z"]]
      @df.sort_order = :descending
      @df.values.should == [["1", "Z"], ["2", "Y"], ["3", "X"]]

      @df.sort_by = :value
      @df.sort_order = :ascending
      @df.values.should == [["1", "Z"], ["2", "Y"], ["3", "X"]]
      @df.sort_order = :descending
      @df.values.should == [["3", "X"], ["2", "Y"], ["1", "Z"]]

      @df.sort_by = :none
      @df.sort_order = :ascending
      @df.values.should == [["2", "Y"], ["1", "Z"], ["3", "X"]]
      @df.sort_order = :descending
      @df.values.should == [["2", "Y"], ["1", "Z"], ["3", "X"]]
    end

    it "return sorted values array as integers" do
      @df.data_type = "integer"
      @df.values = [["2", "Y"], ["10", "Z"], ["3", "X"]]

      @df.sort_by = :value
      @df.sort_order = :ascending
      @df.values.should == [["2", "Y"], ["3", "X"], ["10", "Z"]]
      @df.sort_order = :descending
      @df.values.should == [["10", "Z"], ["3", "X"], ["2", "Y"]]

      @df.sort_by = :none
      @df.sort_order = :ascending
      @df.values.should == [["2", "Y"], ["10", "Z"], ["3", "X"]]
      @df.sort_order = :descending
      @df.values.should == [["2", "Y"], ["10", "Z"], ["3", "X"]]
    end

    context "#initialize_with_values" do
      before(:each) do
        @df.values = [["3", "X"], ["2", "Y"], ["1", "Z"]]
      end

      it "no default value" do
        @df.default_value = nil
        @df.initialize_with_values({})
        @df.value.should == nil
      end

      it "with default value" do
        @df.default_value = "1"
        @df.initialize_with_values({})
        @df.value.should == "1"
      end

      it "with non-matching default value" do
        @df.default_value = "4"
        @df.initialize_with_values({})
        @df.value.should == nil
      end
    end

    it "#automate_key_name" do
      @df.automate_key_name.should == "dialog_drop_down_list"
    end
  end

  describe "#raw_values" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic) }

    context "when the dialog_field is dynamic" do
      let(:dynamic) { true }

      it "returns the values from automate" do

      end
    end

    context "when the dialog_field is not dynamic" do
      let(:dynamic) { false }

      it "returns the values" do

      end
    end
  end

  describe "#values" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic) }

    context "when the dialog_field is dynamic" do
      let(:dynamic) { true }

      before do
        DynamicDialogFieldValueProcessor.stub(:values_from_automate).with(dialog_field).and_return(%w(automate values))
      end

      context "when the raw values are already set" do
        before do
          dialog_field.instance_variable_set(:@raw_values, %w(potato potato))
        end

        it "returns the raw values" do
          expect(dialog_field.values).to eq(%w(potato potato))
        end
      end

      context "when the raw values are not already set" do
        it "returns the values from automate" do
          expect(dialog_field.values).to eq(%w(automate values))
        end
      end
    end

    context "when the dialog_field is not dynamic" do
      let(:dynamic) { false }

      context "when the raw values are already set" do
        before do
          dialog_field.instance_variable_set(:@raw_values, %w(potato potato))
        end

        it "returns the raw values" do
          expect(dialog_field.values).to eq(%w(potato potato))
        end
      end

      context "when the raw values are not already set" do
        before do
          dialog_field.values = %w(original values)
        end

        it "returns the values" do
          expect(dialog_field.values).to eq(%w(original values))
        end
      end
    end
  end
end
