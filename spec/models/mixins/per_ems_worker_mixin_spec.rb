describe PerEmsWorkerMixin do
  before(:each) do
    _guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
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

  describe ".all_valid_ems_in_zone" do
    it "ems enabled" do
      expect(@worker_class.all_valid_ems_in_zone).to be_empty

      @ems.update(:enabled => true)
      @ems.authentications.first.validation_successful
      expect(@worker_class.all_valid_ems_in_zone).to eq([@ems])
    end

    context "worker_wanted or not" do
      before(:each) do
        allow(@worker_class).to receive(:all_ems_in_zone).and_return([@ems])
        allow(@ems).to receive(:enabled).and_return(true)
        allow(@ems).to receive(:authentication_status_ok?).and_return(true)
      end

      it ".worker_wanted? argumet" do
        expect(@ems).to receive(:worker_wanted?).with(@worker_class.name)
        @worker_class.all_valid_ems_in_zone
      end

      it "falsy .worker_wanted?" do
        allow(@ems).to receive(:worker_wanted?).and_return(false)
        expect(@worker_class.all_valid_ems_in_zone).to be_empty
      end

      it "truthy .worker_wanted?" do
        allow(@ems).to receive(:worker_wanted?).and_return(true)
        expect(@worker_class.all_valid_ems_in_zone).to eq([@ems])
      end
    end
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
