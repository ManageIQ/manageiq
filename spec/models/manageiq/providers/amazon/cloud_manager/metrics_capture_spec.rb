require "spec_helper"

describe ManageIQ::Providers::Amazon::CloudManager::MetricsCapture do
  before do
    _guid, _server, @zone = EvmSpecHelper.create_guid_miq_server_zone

    @ems_amazon = FactoryGirl.create(:ems_amazon, :zone => @zone)
  end

  context "#perf_collect_metrics" do
    it "raises an error when no EMS is defined" do
      @vm = FactoryGirl.build(:vm_perf_amazon, :ext_management_system => nil)
      expect { @vm.perf_collect_metrics('interval_name') }.to raise_error
    end

    it "raises an error with no EMS credentials defined" do
      @vm = FactoryGirl.build(:vm_perf_amazon, :ext_management_system => @ems_amazon)
      expect { @vm.perf_collect_metrics('interval_name') }.to raise_error
    end

    it "handles when nothing is collected" do
      @vm = FactoryGirl.build(:vm_perf_amazon, :ext_management_system => @ems_amazon)
      mc = described_class.new(@vm)

      expect(@vm.ext_management_system).to receive(:connect).and_return(double(:metrics => double(:filter => [])))
      expect(@vm).to receive(:perf_capture_object).and_return(mc)

      expect(@vm.perf_collect_metrics('realtime')).to eq([{"amazon-perf-vm" => described_class::VIM_STYLE_COUNTERS},
                                                          {"amazon-perf-vm" => {}}])
    end
  end
end
