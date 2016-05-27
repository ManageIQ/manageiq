describe PerEmsWorkerMixin do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_vmware_with_authentication, :zone => zone)
    @ems_queue_name = "ems_#{@ems.id}"

    # General stubbing for testing any worker (methods called during initialize)
    @worker_record = FactoryGirl.create(:miq_ems_refresh_core_worker, :queue_name => "ems_#{@ems.id}", :miq_server => server)
    @worker_class  = @worker_record.class
  end

  it ".queue_name_for_ems" do
    expect(@worker_class.queue_name_for_ems(nil)).to be_nil
    expect(@worker_class.queue_name_for_ems("foo")).to eq("foo")
    expect(@worker_class.queue_name_for_ems(@ems)).to eq(@ems_queue_name)
  end

  it "#worker_options" do
    expect(@worker_record.worker_options).to eq(:guid => @worker_record.guid, :ems_id => @ems.id)
  end

  context ".start_worker_for_ems" do
    it "works when queue name is passed" do
      queue_name = "foo"
      expect(@worker_class).to receive(:start_worker).with(:queue_name => queue_name)
      @worker_class.start_worker_for_ems(queue_name)
    end

    it "works when ems is passed" do
      expect(@worker_class).to receive(:start_worker).with(:queue_name => @ems_queue_name)
      @worker_class.start_worker_for_ems(@ems)
    end
  end

  context ".stop_worker_for_ems" do
    context "when worker status is started" do
      before(:each) do
        @worker_record.status = MiqWorker::STATUS_STARTED
        @worker_record.save
      end

      it "stops worker when queue name is passed" do
        expect_any_instance_of(@worker_class).to receive(:stop).once
        @worker_class.stop_worker_for_ems(@ems_queue_name)
      end

      it "does not stop worker when non-existent queue_name is passed" do
        expect_any_instance_of(@worker_class).to receive(:stop).never
        @worker_class.stop_worker_for_ems("foo")
      end

      it "stops worker when existing ems is passed" do
        expect_any_instance_of(@worker_class).to receive(:stop).once
        @worker_class.stop_worker_for_ems(@ems)
      end

      it "does not stop worker when non-existent ems is passed" do
        expect_any_instance_of(@worker_class).to receive(:stop).never
        @ems.id += 1
        @worker_class.stop_worker_for_ems(@ems)
      end
    end

    context "when worker status is not started" do
      before(:each) do
        @worker_record.status = MiqWorker::STATUS_STARTING
        @worker_record.save
      end

      it "does not stop worker when queue name is passed" do
        expect_any_instance_of(@worker_class).to receive(:stop).never
        @worker_class.stop_worker_for_ems(@ems_queue_name)
      end

      it "does not stop worker when non-existent queue_name is passed" do
        expect_any_instance_of(@worker_class).to receive(:stop).never
        @worker_class.stop_worker_for_ems("foo")
      end

      it "does not stop worker when existing ems is passed" do
        expect_any_instance_of(@worker_class).to receive(:stop).never
        @worker_class.stop_worker_for_ems(@ems)
      end

      it "does not stop worker when non-existent ems is passed" do
        expect_any_instance_of(@worker_class).to receive(:stop).never
        @ems.id += 1
        @worker_class.stop_worker_for_ems(@ems)
      end
    end
  end
end
