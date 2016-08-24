describe ManageIQ::Providers::Vmware::InfraManager::Provision::Cloning do
  let(:ems)        { FactoryGirl.create(:ems_vmware_with_authentication) }
  let(:ems_folder) { FactoryGirl.create(:ems_folder) }
  let(:host)       { FactoryGirl.create(:host) }
  let(:options)    { {:src_vm_id => template.id, :dest_host => host.id, :placement_folder_name => ems_folder.id, :vm_name => "abc", :number_of_vms => 1} }
  let(:task)       { FactoryGirl.create(:miq_provision_vmware, :userid => user.userid, :source => template, :request_type => 'template', :status => 'Ok', :options => options) }
  let(:template)   { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
  let(:user)       { FactoryGirl.create(:user_admin) }

  it "#prepare_for_clone_task" do
    MiqRegion.seed
    task.after_request_task_create
    expect(task).to receive(:get_network_adapters).and_return({}) # Stub call to with_provider_connection

    task.prepare_for_clone_task

    expect(task.options).to have_attributes(
      :hostname           => "abc",
      :linux_host_name    => "abc",
      :vm_name            => "abc",
      :vm_target_hostname => "abc",
      :vm_target_name     => "abc"
    )
  end
end
