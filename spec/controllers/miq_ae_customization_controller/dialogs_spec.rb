describe MiqAeCustomizationController do
  context "::Dialogs" do
    context "#dialog_delete" do
      before do
        EvmSpecHelper.local_miq_server
        login_as FactoryGirl.create(:user, :features => "dialog_delete")
        allow(controller).to receive(:check_privileges).and_return(true)
      end

      it "flash message displays Dialog Label being deleted" do
        dialog = FactoryGirl.create(:dialog, :label       => "Test Label",
                                             :description => "Test Description",
                                             :buttons     => "submit,reset,cancel"
                                   )

        controller.instance_variable_set(:@sb,
                                         :trees       => {
                                           :dlg_tree => {:active_node => "#{dialog.id}"}
                                         },
                                         :active_tree => :dlg_tree)
        session[:settings] = {:display   => {:locale => 'default'}}

        controller.instance_variable_set(:@settings, :display => {:locale => 'default'})
        allow(controller).to receive(:replace_right_cell)

        # Now delete the Dialog
        controller.instance_variable_set(:@_params, :id => dialog.id)
        controller.send(:dialog_delete)

        # Check for Dialog Label to be part of flash message displayed
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to include("Dialog \"Test Label\": Delete successful")

        expect(controller.send(:flash_errors?)).to be_falsey
      end
    end

    context "#prepare_move_field_value" do
      it "Find ID of a button" do
        controller.instance_variable_set(:@_params, :entry_id => 1)
        controller.instance_variable_set(:@edit, {:field_values => [['test', 100], ['test1', 101], ['test2', 102]]})
        controller.send(:prepare_move_field_value)
        expect(controller.instance_variable_get(:@idx)).to eq(1)
      end
    end

    context "#dialog_edit" do
      before do
        login_as FactoryGirl.create(:user, :features => "dialog_edit")
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
        allow(controller).to receive(:render_flash)
        controller.send(:dialog_edit)
        expect(assigns(:flash_array).first[:message]).to include("Dialog a1 must have at least one Tab")
      end

      it "Any Dialog/Tab with empty group should not be added, and display multiple message for each empty group" do
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
                  :fields      => []
                },
                {
                  :label       => "Box 2",
                  :description => "Box 2",
                  :fields      => []
                }
              ]
            }
          ]
        }
        controller.instance_variable_set(:@lastaction, "replace_right_cell")
        assigns(:edit)[:new] = new_hash
        allow(controller).to receive(:get_node_info)
        allow(controller).to receive(:replace_right_cell)
        allow(controller).to receive(:render_flash)
        controller.instance_variable_set(:@_params, :button => "add")
        controller.send(:dialog_edit)
        expect(assigns(:flash_array).first[:message]).to include("Validation failed:"\
                                                                 " Dialog Dialog 1 / Tab Tab 1 / Box Box 1 must have at least one Element,"\
                                                                 " Dialog Dialog 1 / Tab Tab 1 / Box Box 2 must have at least one Element")
      end

      it "Dialog/Tab with any empty group should not be added" do
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
                  :label       => "Box 2",
                  :description => "Box 2",
                  :fields      => []
                }
              ]
            }
          ]
        }
        controller.instance_variable_set(:@lastaction, "replace_right_cell")
        assigns(:edit)[:new] = new_hash
        allow(controller).to receive(:get_node_info)
        allow(controller).to receive(:replace_right_cell)
        allow(controller).to receive(:render_flash)
        controller.instance_variable_set(:@_params, :button => "add")
        controller.send(:dialog_edit)
        expect(assigns(:flash_array).first[:message]).to include("Validation failed:"\
                                                                 " Dialog Dialog 1 / Tab Tab 1 / Box Box 2 must have at least one Element")
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
                }
              ]
            }
          ]
        }
        assigns(:edit)[:new] = new_hash
        allow(controller).to receive(:get_node_info)
        allow(controller).to receive(:replace_right_cell)
        controller.send(:dialog_edit)
        expect(assigns(:flash_array).first[:message]).to include("Dialog \"Dialog 1\" was added")
        expect(@dialog.dialog_fields.count).to eq(1)
      end
    end

    it "Empty dropdown element has to be invalid" do
      allow(controller).to receive(:x_node) { 'root_-0_-0_-0' }
      controller.instance_variable_set(:@sb, :node_typ => 'element')
      session[:edit] = {
        :field_typ    => "DialogFieldDropDownList",
        :field_values => [],
        :field_label  => 'Dropdown 1',
        :field_name   => 'Dropdown1'
      }
      controller.send(:dialog_validate)
      expect(assigns(:flash_array).first[:message]).to include("Dropdown elements require some entries")
    end

    it "does not require values for a dynamic drop down" do
      allow(controller).to receive(:x_node) { 'root_-0_-0_-0' }
      controller.instance_variable_set(:@sb, :node_typ => 'element')
      session[:edit] = {
        :field_typ         => "DialogFieldDropDownList",
        :field_values      => [],
        :field_label       => 'Dropdown 1',
        :field_name        => 'Dropdown1',
        :field_dynamic     => true,
        :field_entry_point => "entry point"
      }
      controller.send(:dialog_validate)
      expect(assigns(:flash_array)).to eq(nil)
    end
  end
end
