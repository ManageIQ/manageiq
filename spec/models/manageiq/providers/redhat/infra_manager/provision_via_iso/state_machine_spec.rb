describe ManageIQ::Providers::Redhat::InfraManager::ProvisionViaIso do
  context "::StateMachine" do
    before do
      @ems = FactoryGirl.create(:ems_redhat_with_authentication)
      template = FactoryGirl.create(:template_redhat, :ext_management_system => @ems)
      @vm = FactoryGirl.create(:vm_redhat, :ext_management_system => @ems)
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(:miq_provision_redhat_via_iso, :source => template, :destination => @vm, :state => 'pending', :status => 'Ok', :options => options)
      allow(@task).to receive(:destination_image_locked?).and_return(false)
      @iso_image = FactoryGirl.create(:iso_image, :name => "Test ISO Image")
      allow(@task).to receive(:update_and_notify_parent).and_return(nil)
      allow(@task).to receive(:iso_image).and_return(@iso_image)
    end

    include_examples "common rhev state machine methods"

    it "#configure_destination" do
      expect(@task).to receive(:attach_floppy_payload)
      expect(@task).to receive(:boot_from_cdrom)
      @task.configure_destination
    end

    describe "post provisioning" do
      context "version 4" do
        before do
          @vm_service = double("vm_service")
          allow(@vm).to receive(:with_provider_object).and_yield(@vm_service)
          allow(@ems).to receive(:supported_api_versions).and_return([3, 4])
          stub_settings_merge(:ems => { :ems_redhat => { :use_ovirt_engine_sdk => true } })
        end

        it "#post_provision" do
          expect(@vm_service).to receive(:update).with(:payloads => [])
          @task.post_provision
        end
      end

      context "version 3" do
        before do
          @vm_service = double("vm_service")
          allow(@vm).to receive(:with_provider_object).and_return(@vm_service)
          allow(@ems).to receive(:supported_api_versions).and_return([3])
        end

        it "#post_provision" do
          expect(@vm_service).to receive(:detach_floppy)
          @task.post_provision
        end
      end
    end

    describe "#boot_from_cdrom" do
      before do
        @ovirt_services = double("ovirt_services")
        allow(@ovirt_services).to receive(:vm_boot_from_cdrom).with(@task, @iso_image.name)
          .and_return(nil)
        allow(@ovirt_services).to receive(:powered_on_in_provider?).and_return(false)
        allow(@ems).to receive(:ovirt_services).and_return(@ovirt_services)
      end

      context "vm is ready" do
        it "#powered_on_in_provider?" do
          expect(@ovirt_services).to receive(:powered_on_in_provider?).with(@vm)
          @task.boot_from_cdrom
        end
      end

      context "vm is not ready" do
        before do
          exception = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::VmNotReadyToBoot
          allow(@ovirt_services).to receive(:vm_boot_from_cdrom).with(@task, @iso_image.name)
            .and_raise(exception)
        end

        it "requeues the phase" do
          expect(@task).to receive(:requeue_phase)
          @task.boot_from_cdrom
        end
      end
    end
  end
end
