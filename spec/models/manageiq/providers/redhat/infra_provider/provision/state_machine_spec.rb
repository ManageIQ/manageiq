require "spec_helper"

describe ManageIQ::Providers::Redhat::InfraManager::Provision do
  context "::StateMachine" do
    before do
      ems      = FactoryGirl.create(:ems_redhat_with_authentication)
      template = FactoryGirl.create(:template_redhat, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_redhat)
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(:miq_provision_redhat, :source => template, :destination => vm, :state => 'pending', :status => 'Ok', :options => options)
      @task.stub(:miq_request => double("MiqRequest").as_null_object)
      @task.stub(:dest_cluster => FactoryGirl.create(:ems_cluster, :ext_management_system => ems))
    end

    it "#create_destination" do
      @task.should_receive(:determine_placement)

      @task.create_destination
    end

    it "#determine_placement" do
      @task.stub(:placement)

      @task.should_receive(:prepare_provision)

      @task.determine_placement
    end

    it "#start_clone_task" do
      @task.stub(:update_and_notify_parent)
      @task.stub(:log_clone_options)
      @task.stub(:start_clone)

      @task.should_receive(:poll_clone_complete)

      @task.start_clone_task
    end

    context "#poll_clone_complete" do
      it "cloning" do
        @task.should_receive(:clone_complete?).and_return(false)
        @task.should_receive(:requeue_phase)

        @task.poll_clone_complete
      end

      it "clone complete" do
        @task.should_receive(:clone_complete?).and_return(true)
        EmsRefresh.should_receive(:queue_refresh)
        @task.should_receive(:poll_destination_in_vmdb)

        @task.poll_clone_complete
      end
    end

    it "#customize_destination" do
      @task.stub(:get_provider_destination).and_return(nil)
      @task.stub(:update_and_notify_parent)

      @task.should_receive(:configure_container)
      @task.should_receive(:attach_floppy_payload)
      @task.should_receive(:poll_destination_powered_off_in_provider)

      @task.customize_destination
    end

    it "#poll_destination_powered_off_in_provider" do
      ManageIQ::Providers::Redhat::InfraManager::Vm.any_instance.should_receive(:with_provider_object).and_return(:state => "up")
      @task.should_receive(:requeue_phase)

      @task.poll_destination_powered_off_in_provider
    end

    context "#poll_destination_powered_on_in_provider" do
      it "requeues if the VM didn't start" do
        ManageIQ::Providers::Redhat::InfraManager::Vm.any_instance.stub(:with_provider_object => {:state => "down"})
        expect(@task).to receive(:requeue_phase)

        @task.poll_destination_powered_on_in_provider

        expect(@task.phase_context[:power_on_wait_count]).to eq(1)
      end

      it "moves on if the vm started" do
        ManageIQ::Providers::Redhat::InfraManager::Vm.any_instance.stub(:with_provider_object => {:state => "up"})
        expect(@task).to receive(:poll_destination_powered_off_in_provider)

        @task.poll_destination_powered_on_in_provider

        expect(@task.phase_context[:power_on_wait_count]).to be_nil
      end

      it "raises if the vm failed to start" do
        @task.phase_context[:power_on_wait_count] = 121

        expect { @task.poll_destination_powered_on_in_provider }.to raise_error(MiqException::MiqProvisionError)
      end
    end
  end
end
