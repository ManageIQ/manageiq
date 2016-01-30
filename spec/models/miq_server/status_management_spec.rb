describe MiqServer do
  context "StatusManagement" do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    # for now, just making sure there are no syntax errors
    it ".log_status" do
      expect(MiqServer).to receive(:log_system_status).once
      MiqServer.log_status
    end

    it ".status_update" do
      require 'miq-process'
      allow(MiqProcess).to receive(:processInfo).and_return(
        :pid                   => 94_660,
        :memory_usage          => 246_824_960,
        :memory_size           => 2_792_611_840,
        :percent_memory        => "1.4",
        :percent_cpu           => "1.0",
        :cpu_time              => 660,
        :priority              => "31",
        :name                  => "ruby",
        :proportional_set_size => 198_721_987
      )

      described_class.status_update
      @miq_server.reload
      expect(@miq_server.os_priority).to eq 31
      expect(@miq_server.memory_usage).to eq 246_824_960
      expect(@miq_server.percent_memory).to eq 1.4
      expect(@miq_server.percent_cpu).to eq 1.0
      expect(@miq_server.memory_size).to eq 2_792_611_840
      expect(@miq_server.proportional_set_size).to eq 198_721_987
    end
  end
end
