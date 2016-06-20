describe MiqAeCustomizationController do
  context "::OldDialogs" do
    context "#old_dialogs_button_operation" do
      it "Only non-default dialogs should get deleted" do
        dialog1 = FactoryGirl.create(:miq_dialog, :name        => "Test_Dialog1",
                                                  :description => "Test Description 1",
                                                  :default     => true
                                    )
        dialog2 = FactoryGirl.create(:miq_dialog, :name        => "Test_Dialog2",
                                                  :description => "Test Description 2",
                                                  :default     => false
                                    )
        controller.instance_variable_set(:@sb,
                                         :active_tree => :old_dialogs_tree,
                                         :trees       => {
                                           :old_dialogs_tree => {
                                             :active_node => "xx-MiqDialog_MiqProvisionWorkflow"}
                                         }
                                        )
        allow(controller).to receive(:get_node_info)
        allow(controller).to receive(:replace_right_cell)

        # Now delete the Dialog
        controller.instance_variable_set(:@_params, "check_#{dialog1.id}" => "1", "check_#{dialog2.id}" => "1")
        controller.send(:old_dialogs_button_operation, 'destroy', 'Test Dialog')

        # Check for Dialog Label to be part of flash message displayed
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to include("Default Dialog \"Test_Dialog1\" cannot be deleted")
        expect(controller.send(:flash_errors?)).to be_truthy
        expect(flash_messages.last[:message]).to include("Dialog \"Test Description 2\": Delete successful")
      end

      it "Default Dialog should not be deleted" do
        dialog = FactoryGirl.create(:miq_dialog, :name        => "Test_Dialog",
                                                 :description => "Test Description",
                                                 :default     => true
                                   )
        controller.instance_variable_set(:@sb,
                                         :trees       => {:old_dialogs_tree => {:active_node => "odg-#{dialog.id}"}},
                                         :active_tree => :old_dialogs_tree)
        allow(controller).to receive(:replace_right_cell)

        # Now delete the Dialog
        controller.instance_variable_set(:@_params, :id => dialog.id)
        controller.send(:old_dialogs_button_operation, 'destroy', 'Test Dialog')

        # Check for Dialog Label to be part of flash message displayed
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to include("Default Dialog \"Test_Dialog\" cannot be deleted")

        expect(controller.send(:flash_errors?)).to be_truthy
      end
    end

    context 'Adding a new Dialog' do
      render_views

      it 'will show a flash error without Dialog Type' do
        allow(controller).to receive(:load_edit).and_return(true)
        controller.instance_variable_set(:@_params, :button => 'add',
                                                    :id     => 'new')
        controller.instance_variable_set(:@edit, :new    => {:name        => 'name',
                                                             :description => 'description',
                                                             :dialog_type => '',
                                                             :content     => '',},
                                                 :dialog => MiqDialog.new)
        allow(controller).to receive(:render)
        controller.send(:old_dialogs_update)

        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to include('Dialog Type must be selected')
        expect(controller.send(:flash_errors?)).to be_truthy
      end
    end
  end
end
