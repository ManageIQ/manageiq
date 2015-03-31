require "spec_helper"

describe ApplicationHelper do
  context "::Dialogs" do
    describe "#dialog_dropdown_select_values" do

      before do
        val_array = [["cat", "Cat"], ["dog", "Dog"]]
        @val_array_reversed = val_array.collect(&:reverse)
        @field = DialogFieldDropDownList.new(:values => val_array)
      end

      it "not required" do
        @field.required = false
        values = helper.dialog_dropdown_select_values(@field, nil)
        values.should == [["<None>", nil]] + @val_array_reversed
      end

      it "required, nil selected" do
        @field.required = true
        values = helper.dialog_dropdown_select_values(@field, nil)
        values.should == [["<Choose>", nil]] + @val_array_reversed
      end

      it "required, non-nil selected" do
        @field.required = true
        values = helper.dialog_dropdown_select_values(@field, "cat")
        values.should == @val_array_reversed
      end
    end

    describe "#textbox_tag_options" do
      let(:dialog_field) { active_record_instance_double("DialogField", :id => "100", :read_only => read_only) }

      context "when the field is read_only" do
        let(:read_only) { true }

        it "returns the tag options with a disabled true" do
          expect(helper.textbox_tag_options(dialog_field, "url")).to eq({
            :maxlength => 50,
            :class     => "dynamic-text-box-100",
            :disabled  => true,
            :title     => "This element is disabled because it is read only"
          })
        end
      end

      context "when the dialog field is not read only" do
        let(:read_only) { false }

        it "returns the tag options with a data-miq-observe" do
          expect(helper.textbox_tag_options(dialog_field, "url")).to eq({
            :maxlength         => 50,
            :class             => "dynamic-text-box-100",
            "data-miq_observe" => "{\"interval\":\".5\",\"url\":\"url\"}"
          })
        end
      end
    end
  end
end
