describe ManageIQ::Providers::Redhat::InfraManager::Provision do
  context "::StateMachine" do
    before do
      ems      = FactoryGirl.create(:ems_redhat_with_authentication)
      template = FactoryGirl.create(:template_redhat, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_redhat)
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(:miq_provision_redhat, :source => template, :destination => vm, :state => 'pending', :status => 'Ok', :options => options)
      allow(@task).to receive_messages(:miq_request => double("MiqRequest").as_null_object)
      allow(@task).to receive_messages(:dest_cluster => FactoryGirl.create(:ems_cluster, :ext_management_system => ems))
    end

    include_examples "common rhev state machine methods"
    include_examples "polling destination power status in provider"

    it "#create_destination" do
      expect(@task).to receive(:determine_placement)

      @task.create_destination
    end

    it "#determine_placement" do
      allow(@task).to receive(:placement)

      expect(@task).to receive(:prepare_provision)

      @task.determine_placement
    end

    it "#start_clone_task" do
      allow(@task).to receive(:update_and_notify_parent)
      allow(@task).to receive(:log_clone_options)
      allow(@task).to receive(:start_clone)

      expect(@task).to receive(:poll_clone_complete)

      @task.start_clone_task
    end

    context "#poll_clone_complete" do
      it "cloning" do
        expect(@task).to receive(:clone_complete?).and_return(false)
        expect(@task).to receive(:requeue_phase)

        @task.poll_clone_complete
      end

      it "clone complete" do
        expect(@task).to receive(:clone_complete?).and_return(true)
        expect(EmsRefresh).to receive(:queue_refresh)
        expect(@task).to receive(:poll_destination_in_vmdb)

        @task.poll_clone_complete
      end
    end

    context "#autostart_destination" do
      it "with use_cloud_init" do
        expect(@task).to receive(:phase_context).and_return(:boot_with_cloud_init => true)
        expect(@task).to receive(:get_option).with(:vm_auto_start).and_return(true)
        allow(@task).to receive(:for_destination)
        expect(@task).to receive(:update_and_notify_parent)

        rhevm_vm = double("RHEVM VM")
        expect(@task).to receive(:get_provider_destination).and_return(rhevm_vm)

        xml = double("XML")
        expect(xml).to receive(:use_cloud_init).with(true)
        expect(rhevm_vm).to receive(:start).and_yield(xml)

        expect(@task).to receive(:post_create_destination)

        @task.autostart_destination
      end

      it "without use_cloud_init" do
        expect(@task).to receive(:phase_context).and_return({})
        expect(@task).to receive(:get_option).with(:vm_auto_start).and_return(true)
        allow(@task).to receive(:for_destination)
        expect(@task).to receive(:update_and_notify_parent)

        rhevm_vm = double("RHEVM VM")
        expect(@task).to receive(:get_provider_destination).and_return(rhevm_vm)

        xml = double("XML")
        expect(xml).not_to receive(:use_cloud_init)
        expect(rhevm_vm).to receive(:start).and_yield(xml)

        expect(@task).to receive(:post_create_destination)

        @task.autostart_destination
      end
    end

    it "#configure_destination" do
      expect(@task).to receive(:configure_cloud_init)
      expect(@task).to receive(:poll_destination_powered_off_in_provider)
      @task.configure_destination
    end
  end
end
