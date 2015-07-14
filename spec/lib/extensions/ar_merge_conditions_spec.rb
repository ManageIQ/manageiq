require "spec_helper"

describe ActiveRecord::Base do
  context "calling apply_legacy_finder_options" do
    before(:each) do
      @vm = FactoryGirl.create(:vm_vmware)
      @perf = FactoryGirl.create(
        :metric_rollup_vm_daily,
        :resource_id  => @vm.id,
        :timestamp    => "2010-04-14T00:00:00Z",
        :time_profile => @time_profile
      )

      # Typical includes for rendering daily metrics charts
      @include = {
        :max_derived_cpu_available => {},
        :max_derived_cpu_reserved => {},
        :min_cpu_usagemhz_rate_average => {},
        :max_cpu_usagemhz_rate_average => {},
        :min_cpu_usage_rate_average => {},
        :max_cpu_usage_rate_average => {},
        :v_pct_cpu_ready_delta_summation => {},
        :v_pct_cpu_wait_delta_summation => {},
        :v_pct_cpu_used_delta_summation => {},
        :max_derived_memory_available => {},
        :max_derived_memory_reserved => {},
        :min_derived_memory_used => {},
        :max_derived_memory_used => {},
        :min_disk_usage_rate_average => {},
        :max_disk_usage_rate_average => {},
        :min_net_usage_rate_average => {},
        :max_net_usage_rate_average => {},
        :v_derived_storage_used => {},
        :resource => {}

      }
    end
    it "should not raise an error when a polymorphic reflection is included" do
      result = nil
      expect do
        result = MetricRollup.apply_legacy_finder_options(:include => @include).to_a
      end.not_to raise_error

      result.length.should == 1
    end
  end
end

