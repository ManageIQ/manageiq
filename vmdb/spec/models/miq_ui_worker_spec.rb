require "spec_helper"

describe MiqUiWorker do
  it ".build_command_line" do
    run1 = MiqUiWorker.build_command_line(:arg1 => true)
    run2 = MiqUiWorker.build_command_line(:arg1 => true)
    run1.should == run2         # same values
    run1.should_not equal run2  # different Objects
  end

  context ".all_ports_in_use" do
    before do
      require 'util/miq-process'
      MiqProcess.stub(:is_worker?).and_return(false)

      guid, server1, @zone= EvmSpecHelper.create_guid_miq_server_zone

      @worker1 = FactoryGirl.create(:miq_ui_worker, :miq_server => server1, :uri => "http://0.0.0.0:3000", :status => 'started')
      @worker2 = FactoryGirl.create(:miq_ui_worker, :miq_server => server1, :uri => "http://0.0.0.0:3001", :status => 'started')
    end

    it "normal case" do
      MiqUiWorker.all_ports_in_use.sort.should == [3000, 3001]
    end

    it "started vs. stopped workers" do
      @worker1.update_attribute(:status, "stopped")
      MiqUiWorker.all_ports_in_use.sort.should == [3001]
    end

    it "current vs. remote servers" do
      server2 = FactoryGirl.create(:miq_server, :zone => @zone)
      @worker2.miq_server = server2
      @worker2.save
      MiqUiWorker.all_ports_in_use.should == [3000]
    end
  end

end
