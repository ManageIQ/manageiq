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

    context "#dialog_edit" do
      before do
        seed_specific_product_features("dialog_edit")
        @dialog = FactoryGirl.create(:dialog,
                                     :label       => "Test Label",
                                     :description => "Test Description"
        )
        tree_hash = {
          :active_tree => :dialog_edit_tree,
          :trees       => {
            :dialog_edit_tree => {
              :active_node => "root"
            }
          }
        }
        controller.instance_variable_set(:@_params, :button => "add")
        controller.instance_variable_set(:@sb, tree_hash)
        new = {:label => "a1", :description => "a1", :buttons => ["submit"], :tabs => []}
        edit = {
          :dialog         => @dialog,
          :key            => 'dialog_edit__new',
          :new            => new,
          :dialog_buttons => ['submit, cancel']
        }

        controller.instance_variable_set(:@edit, edit)
        session[:edit] = edit
      end

      it "Dialog with out Dialog fields should not be saved" do
        controller.stub(:render_flash)
        controller.send(:dialog_edit)
        assigns(:flash_array).first[:message].should include("Dialog must have at least one Element")
      end

      it "Adds a Dialog with Tab/Groups/Field" do
        new_hash = {
          :label       => "Dialog 1",
          :description => "Dialog 1",
          :buttons     => ["submit"],
          :tabs        => [
            {
              :label       => "Tab 1",
              :description => "Tab 1",
              :groups      => [
                {
                  :label       => "Box 1",
                  :description => "Box 1",
                  :fields      => [
                    {
                      :label         => "Field 1",
                      :description   => "Field 1",
                      :typ           => "DialogFieldCheckBox",
                      :name          => "Field1",
                      :default_value => false
                    }
                  ]
                },
                {
                  :label => "Box 2", :description => "Box 2"
                }
              ]
            }
          ]
        }
        assigns(:edit)[:new] = new_hash
        controller.stub(:get_node_info)
        controller.stub(:replace_right_cell)
        controller.send(:dialog_edit)
        assigns(:flash_array).first[:message].should include("Dialog \"Dialog 1\" was added")
        @dialog.dialog_fields.count.should eq(1)
      end
    end
  end
end
