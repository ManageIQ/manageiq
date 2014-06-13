require "spec_helper"

describe ApplicationHelper do

  context "::Dialogs" do
    describe "#dialog_dropdown_select_values" do

      before do
        val_array = [["cat", "Cat"], ["dog", "Dog"]]
        @val_array_reversed = val_array.collect{|v| v.reverse}
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
  end
end
