describe ManageIQ::Providers::Redhat::InfraManager::ProvisionViaIso do
  context "::StateMachine" do
    before do
      ems      = FactoryGirl.create(:ems_redhat_with_authentication)
      template = FactoryGirl.create(:template_redhat, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_redhat)
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(:miq_provision_redhat_via_iso, :source => template, :destination => vm, :state => 'pending', :status => 'Ok', :options => options)
    end

    include_examples "common rhev state machine methods"

    it "#configure_destination" do
      expect(@task).to receive(:attach_floppy_payload)
      expect(@task).to receive(:boot_from_cdrom)
      @task.configure_destination
    end
  end
end
