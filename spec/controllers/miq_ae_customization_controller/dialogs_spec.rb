describe MiqAeCustomizationController do
  context "::Dialogs" do
    context "#dialog_get_form_vars_field" do
      it "when initial tree load multi default is false" do
        controller.x_node = "root_942-0_1053-0"
        edit_new = {:new => { :tabs => [{:groups => [{:fields =>[{}]}]}]}}
        controller.instance_variable_set(:@edit, edit_new)
        controller.instance_variable_set(:@_params, :field_typ => "DialogFieldDropDownList")

        controller.send(:dialog_get_form_vars_field)

        edit_hash = controller.instance_variable_get(:@edit)
        expect(edit_hash[:field_multi_value]).to be false
        expect(edit_hash.fetch_path(:new, :tabs, 0, :groups, 0, :fields, 0, :multi_value)).to be false
      end

      it "when not initial tree load multi default still false" do
        controller.x_node = "root_942-0_1053-0"
        field = {
          :id          => 9463,
          :label       => "first_text_box",
          :description => "first_text_box",
          :typ         => "DialogFieldTextBox",
          :tab_id      => 942,
          :group_id    => 1053,
          :order       => 0,
          :multi_value => false
        }
        edit_new = {:new => { :tabs => [{:groups => [{:fields =>[field]}]}]}}
        controller.instance_variable_set(:@edit, edit_new)
        controller.instance_variable_set(:@_params, :field_typ => "DialogFieldDropDownList")

        controller.send(:dialog_get_form_vars_field)

        edit_hash = controller.instance_variable_get(:@edit)
        expect(edit_hash[:field_multi_value]).to be false
        expect(edit_hash.fetch_path(:new, :tabs, 0, :groups, 0, :fields, 0, :multi_value)).to be false
      end

      it "gets correct value on load of edit" do
        controller.x_node = "root_942-0_1053-0"
        edit_new = {:field_typ => "DialogFieldDropDownList", :new => { :tabs => [{:groups => [{:fields =>[{}]}]}]}}
        controller.instance_variable_set(:@edit, edit_new)
        controller.instance_variable_set(:@_params, :field_multi_value => "true")

        controller.send(:dialog_get_form_vars_field)

        edit_hash = controller.instance_variable_get(:@edit)
        expect(edit_hash[:field_multi_value]).to be true
        expect(edit_hash.fetch_path(:new, :tabs, 0, :groups, 0, :fields, 0, :multi_value)).to be true
      end
    end

    context "#dialog_edit_set_form_vars" do
      it "reset multiselect on edit from session" do
        controller.x_node = "root_942-0_1053-0_-0"
        field = {
          :id          => 9463,
          :label       => "first_drop_down",
          :description => "first_drop_down",
          :typ         => "DialogFieldDropDownList",
          :tab_id      => 942,
          :group_id    => 1053,
          :multi_value => true
        }
        edit_new = {:new => { :tabs => [{:groups => [{:fields =>[field]}]}]}}
        session[:edit] = edit_new

        controller.send(:dialog_edit_set_form_vars)

        edit_hash = controller.instance_variable_get(:@edit)
        expect(edit_hash.fetch_path(:new, :tabs, 0, :groups, 0, :fields, 0, :multi_value)).to be true
      end
    end

    context "#dialog_set_record_vars" do
      let(:dialog) do
        FactoryGirl.create(
          :dialog,
          :label       => "Test Label",
          :description => "Test Description",
          :buttons     => "submit,reset,cancel"
        )
      end
      it "loads record from not the session" do
        field = {
          :id                => 9463,
          :name              => "foo",
          :label             => "first_drop_down",
          :description       => "first_drop_down",
          :typ               => "DialogFieldDropDownList",
          :tab_id            => 942,
          :group_id          => 1053,
          :order             => 0,
          :required          => false,
          :sort_by           => :value,
          :sort_order        => "ascending",
          :data_type         => Integer,
          :values            => [1, 2, 3],
          :default_value     => 1,
          :force_multi_value => nil
        }
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
                  :fields      => [field]
                }
              ]
            }
          ]
        }
        controller.instance_variable_set(:@edit, :new => new_hash, :dialog_buttons => [])

        controller.send(:dialog_set_record_vars, dialog, "foo")

        expect(dialog.dialog_tabs.first.dialog_groups.first.dialog_fields.first.options[:force_multi_value]).to be nil
      end
    end

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
                                           :dlg_tree => {:active_node => dialog.id.to_s}
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
        controller.instance_variable_set(:@edit, :field_values => [['test', 100], ['test1', 101], ['test2', 102]])
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

      it "Adds a Dialog with Tab/Groups/Fields & adds data_type for textbox field" do
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
                    },
                    {
                      :label         => "Field 2",
                      :description   => "Field 2",
                      :typ           => "DialogFieldTextBox",
                      :name          => "Field2",
                      :default_value => "Foo",
                      :data_typ      => "integer"
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
        allow(controller).to receive(:render_flash)
        controller.send(:dialog_edit)
        expect(assigns(:flash_array).first[:message]).to include("Dialog \"Dialog 1\" was added")
        expect(@dialog.dialog_fields.count).to eq(2)
        expect(@dialog.dialog_fields.last[:data_type]).to eq("integer")
      end

      it "initializes Value Type of new text box to String" do
        allow(controller).to receive(:x_node) { 'root_-0_-0_-0' }
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
                      :typ => "DialogFieldTextBox",
                    }
                  ]
                }
              ]
            }
          ]
        }
        assigns(:edit)[:new] = new_hash
        controller.instance_variable_set(:@_params, :id => 'new', :field_typ => "DialogFieldTextBox")
        controller.instance_variable_set(:@sb, :node_typ => 'element')
        expect(controller).to receive(:render)
        controller.send(:dialog_form_field_changed)
        expect(assigns(:edit)[:field_data_typ]).to eq("string")
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

    context "#dialog_add_tab" do
      before do
        login_as FactoryGirl.create(:user, :features => ["dialog_add_tab"])
        @dialog = FactoryGirl.create(:dialog,
                                     :label       => "Test Label",
                                     :description => "Test Description"
                                    )
        tree_hash = {
          :node_typ    => 'tab',
          :active_tree => :dialog_edit_tree,
          :trees       => {
            :dialog_edit_tree => {
              :active_node => "root_-1"
            }
          }
        }
        controller.instance_variable_set(:@sb, tree_hash)
        new_hash = {
          :label       => "D1",
          :description => "D1",
          :buttons     => ["submit"],
          :tabs        => [
            {
              :label       => "T1",
              :description => "T1"
            }
          ]
        }
        edit = {
          :dialog         => @dialog,
          :tab_label      => 'T1',
          :key            => "dialog_edit__#{@dialog.id}",
          :new            => new_hash,
          :dialog_buttons => ['submit, cancel']
        }

        controller.instance_variable_set(:@edit, edit)
        session[:edit] = edit
      end

      it "do not allow adding another tab until one in progress has children" do
        new_hash = {
          :label       => "Dialog 1",
          :description => "Dialog 1",
          :buttons     => ["submit"],
          :tabs        => [
            {:label => "Tab 1", :description => "Tab 1"}
          ]
        }
        assigns(:edit)[:new] = new_hash
        controller.instance_variable_set(:@_params, :id => @dialog.id.to_s, :typ => "tab", :pressed => "dialog_add_tab")
        allow(controller).to receive(:render)
        controller.send(:x_button)
        expect(@dialog.dialog_tabs[0].errors.messages[:base]).to include("Tab Tab 1 must have at least one Box")
      end
    end
  end
end
