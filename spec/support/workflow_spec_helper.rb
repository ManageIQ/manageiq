module Spec
  module Support
    module WorkflowHelper
      def stub_dialog(method = :get_dialogs)
        allow_any_instance_of(described_class).to receive(method).and_return(:dialogs => {})
      end

      def stub_get_next_vm_name(vm_name = "New VM")
        allow(MiqProvision).to receive(:get_next_vm_name).and_return(vm_name)
      end

      def assert_automate_dialog_lookup(user, category, platform, method = 'get_pre_dialog_name', dialog_name = nil)
        no_attrs = double(:attributes => [])
        stub_automate_workspace(dialog_name, user, no_attrs, no_attrs, dialog_name)

        expect(MiqAeEngine).to receive(:create_automation_object).with(
          "REQUEST",
          hash_including(
            'request'                   => 'UI_PROVISION_INFO',
            'message'                   => method,
            'dialog_input_request_type' => 'template',
            'dialog_input_target_type'  => 'vm',
            'platform_category'         => category,
            'platform'                  => platform,
          ),
          anything).and_return(dialog_name)
      end

      def assert_automate_vm_name_lookup(user, vm_name = 'vm_name')
        stub_automate_workspace("get_vmname_url", user, vm_name)

        expect(MiqAeEngine).to receive(:create_automation_object).with(
          "REQUEST",
          hash_including(
            'request'    => 'UI_PROVISION_INFO',
            'message'    => 'get_vmname',
            'User::user' => user.id
          ),
          anything).and_return("get_vmname_url")
      end

      def stub_automate_workspace(url, user, *result)
        workspace_stub = double("Double for #stub_automate_workspace")
        expect(workspace_stub).to receive(:instantiate).with(url, user, nil)
        expect(workspace_stub).to receive(:root).and_return(*result)
        allow(workspace_stub).to  receive(:to_expanded_xml).and_return(*result)
        expect(MiqAeEngine::MiqAeWorkspaceRuntime).to receive(:new).and_return(workspace_stub)
      end
    end
  end
end
