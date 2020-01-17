RSpec.describe MiqServer do
  context "StatusManagement" do
    before do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    # for now, just making sure there are no syntax errors
    it ".log_status" do
      expect(MiqServer).to receive(:log_system_status).once
      MiqServer.log_status
    end

    it ".status_update" do
      require 'miq-process'
      require 'miq-system'
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

      allow(MiqSystem).to receive(:memory).and_return(
        :MemFree   => 118_706_176,
        :MemTotal  => 2_967_281_664,
        :SwapFree  => 6_291_300_352,
        :SwapTotal => 6_291_451_904
      )

      described_class.status_update
      @miq_server.reload

      expect(@miq_server.os_priority).to eq 31
      expect(@miq_server.memory_usage).to eq 246_824_960
      expect(@miq_server.percent_memory).to eq 1.4
      expect(@miq_server.percent_cpu).to eq 1.0
      expect(@miq_server.memory_size).to eq 2_792_611_840
      expect(@miq_server.proportional_set_size).to eq 198_721_987

      expect(@miq_server.system_memory_free).to eq 118_706_176
      expect(@miq_server.system_memory_used).to eq(2_967_281_664 - 118_706_176)
      expect(@miq_server.system_swap_free).to eq 6_291_300_352
      expect(@miq_server.system_swap_used).to eq(6_291_451_904 - 6_291_300_352)
    end
  end
end
