require "spec_helper"

describe ManageIQ::Providers::Microsoft::InfraManager::Provision do
  context "::StateMachine" do
    before do
      ems      = FactoryGirl.create(:ems_microsoft_with_authentication)
      template = FactoryGirl.create(:template_microsoft, :ext_management_system => ems)
      vm       = FactoryGirl.create(:vm_microsoft)
      @host    = FactoryGirl.create(:host_microsoft, :ext_management_system => ems)
      @storage = FactoryGirl.create(:storage)
      options  = {:src_vm_id => template.id}

      @task = FactoryGirl.create(
        :miq_provision_microsoft,
        :source      => template,
        :destination => vm,
        :state       => 'pending',
        :status      => 'Ok',
        :options     => options)

      @task.stub(:miq_request => double("MiqRequest").as_null_object)
      @task.stub(:dest_host => @host)
      @task.stub(:dest_storage => @storage)
    end

    it "#create_destination" do
      expect(@task).to receive(:determine_placement)
      @task.create_destination
    end

    it "#determine_placement" do
      allow(@task).to receive(:placement).and_return(@host, @storage)
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

    it "#customize_destination" do
      allow(@task).to receive(:update_and_notify_parent)
      expect(@task).to receive(:autostart_destination)
      @task.customize_destination
    end
  end
end
