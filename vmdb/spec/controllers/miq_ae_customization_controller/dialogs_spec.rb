require "spec_helper"
include UiConstants

describe MiqAeCustomizationController do
  context "::Dialogs" do
    context "#dialog_delete" do
      before do
        seed_specific_product_features("dialog_delete")
      end

      it "flash message displays Dialog Label being deleted" do
        dialog = FactoryGirl.create(:dialog, :label            => "Test Label",
                                             :description      => "Test Description",
                                             :buttons          => "submit,reset,cancel"
                                   )

        controller.instance_variable_set(:@sb,
                                         {:trees => {
                                          :dlg_tree => {:active_node => "#{dialog.id}"}
                                         },
                                          :active_tree => :dlg_tree
                                         })

        controller.stub(:replace_right_cell)

        # Now delete the Dialog
        controller.instance_variable_set(:@_params, {:id => dialog.id})
        controller.send(:dialog_delete)

        # Check for Dialog Label to be part of flash message displayed
        flash_messages = assigns(:flash_array)
        flash_messages.first[:message].should include("Dialog \"Test Label\": Delete successful")

        controller.send(:flash_errors?).should be_false
      end
    end

    context "#prepare_move_field_value" do
      it "Find ID of a button" do
        controller.instance_variable_set(:@_params, {:entry_id => 1 })
        controller.instance_variable_set(:@edit, {:field_values => [['test',100], ['test1',101], ['test2',102]]})
        controller.send(:prepare_move_field_value)
        expect(controller.instance_variable_get(:@idx)).to eq(1)
      end
    end
  end
end
