require_relative "../aws_helper"

describe ManageIQ::Providers::Amazon::CloudManager::MetricsCapture do
  let(:ems) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:vm) { FactoryGirl.build(:vm_perf_amazon, :ext_management_system => ems) }

  context "#perf_collect_metrics" do
    it "raises an error when no EMS is defined" do
      vm = FactoryGirl.build(:vm_perf_amazon, :ext_management_system => nil)
      expect { vm.perf_collect_metrics('interval_name') }.to raise_error(RuntimeError, /No EMS defined/)
    end

    it "raises an error with no EMS credentials defined" do
      vm = FactoryGirl.build(:vm_perf_amazon, :ext_management_system => FactoryGirl.create(:ems_amazon))
      expect { vm.perf_collect_metrics('interval_name') }.to raise_error(RuntimeError, /no credentials defined/)
    end

    it "handles when nothing is collected" do
      stubbed_responses = {
        :cloudwatch => {
          :list_metrics => {}
        }
      }
      with_aws_stubbed(stubbed_responses) do
        expect(vm.perf_collect_metrics('realtime')).to eq([
          {"amazon-perf-vm" => described_class::VIM_STYLE_COUNTERS},
          {"amazon-perf-vm" => {}}
        ])
      end
    end

    it "handles when metrics are collected for only one counter" do
      stubbed_responses = {
        :cloudwatch => {
          :list_metrics          => {
            :metrics => [
              :metric_name => "NetworkIn",
              :namespace   => "Namespace"
            ]
          },
          :get_metric_statistics => {
            :datapoints => [
              :timestamp => Time.new(1999).utc,
              :average   => 1.0
            ]
          }
        }
      }
      with_aws_stubbed(stubbed_responses) do
        expect(vm.perf_collect_metrics('realtime')).to eq([
          {"amazon-perf-vm" => described_class::VIM_STYLE_COUNTERS},
          {"amazon-perf-vm" => {}}
        ])
      end
    end
  end
end
