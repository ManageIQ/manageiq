require "spec_helper"

describe MiqProvisionMicrosoft do
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
      @task.should_receive(:determine_placement)
      @task.create_destination
    end

    it "#determine_placement" do
      @task.stub(:placement).and_return(@host, @storage)
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
      @task.stub(:update_and_notify_parent)
      @task.should_receive(:autostart_destination)
      @task.customize_destination
    end
  end
end
