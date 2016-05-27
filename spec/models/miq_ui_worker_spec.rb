describe MiqUiWorker do
  context ".all_ports_in_use" do
    before do
      require 'util/miq-process'
      allow(MiqProcess).to receive(:is_worker?).and_return(false)

      _guid, server1, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @worker1 = FactoryGirl.create(:miq_ui_worker, :miq_server => server1, :uri => "http://0.0.0.0:3000", :status => 'started')
      @worker2 = FactoryGirl.create(:miq_ui_worker, :miq_server => server1, :uri => "http://0.0.0.0:3001", :status => 'started')
    end

    it "normal case" do
      expect(MiqUiWorker.all_ports_in_use.sort).to eq([3000, 3001])
    end

    it "started vs. stopped workers" do
      @worker1.update_attribute(:status, "stopped")
      expect(MiqUiWorker.all_ports_in_use.sort).to eq([3001])
    end

    it "current vs. remote servers" do
      server2 = FactoryGirl.create(:miq_server, :zone => @zone)
      @worker2.miq_server = server2
      @worker2.save
      expect(MiqUiWorker.all_ports_in_use).to eq([3000])
    end
  end
end
