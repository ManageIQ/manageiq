require "spec_helper"

describe ManageIQ::Providers::Redhat::InfraManager::ProvisionViaPxe do
  context "::StateMachine" do
    before do
      ems      = FactoryGirl.create(:ems_redhat_with_authentication)
      template = FactoryGirl.create(:template_redhat, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_redhat)
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(:miq_provision_redhat_via_pxe, :source => template, :destination => vm,
                                 :state => 'pending', :status => 'Ok', :options => options)
    end

    it "#customize_destination" do
      allow(@task).to receive(:get_provider_destination).and_return(nil)
      allow(@task).to receive(:update_and_notify_parent)

      expect(@task).to receive(:configure_container)
      expect(@task).to receive(:configure_destination)
      @task.customize_destination
    end

    it "#configure_destination" do
      expect(@task).to receive(:create_pxe_configuration_file)
      @task.configure_destination
    end
  end
end
