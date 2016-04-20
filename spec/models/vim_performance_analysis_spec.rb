RSpec.describe VimPerformanceAnalysis do
  let(:tag_text) { "operations/good" }
  let(:tag_good) { FactoryGirl.create(:tag, :name => "/managed/#{tag_text}") }
  let(:tag_bad)  { FactoryGirl.create(:tag, :name => "/managed/operations/bad") }
  let(:time_profile) { FactoryGirl.create(:time_profile_with_rollup, :profile => {:tz => "UTC"}) }

  let(:user) { FactoryGirl.create(:user_admin) }

  let(:ems) { FactoryGirl.create(:ems_vmware) }

  let(:good_day) { DateTime.current - 2.day }
  let(:bad_day)  { DateTime.current - 4.months }
  let(:vm1) do
    FactoryGirl.create(:vm_vmware, :name => "test_vm", :tags => [tag_good], :ext_management_system => ems).tap do |vm|
      [7, 8, 9, 10].each do |hour|
        add_rollup(vm, (good_day + hour.hours).to_s, tag_text)
        add_rollup(vm, (bad_day + hour.hours).to_s, tag_text)
      end
      vm.save!
    end
  end

  let(:storage) { FactoryGirl.create(:storage_target_vmware) }
  let(:host1) do
    FactoryGirl.create(:host,
                       :hardware => FactoryGirl.create(:hardware,
                                                       :memory_mb       => 8124,
                                                       :cpu_total_cores => 1,
                                                       :cpu_speed       => 9576),
                       :vms      => [vm1],
                       :storages => [storage])
  end

  let(:ems_cluster) do
    FactoryGirl.create(:ems_cluster, :ext_management_system => ems, :hosts => [host1])
  end

  before do
    MiqRegion.seed
    EvmSpecHelper.local_miq_server
  end

  describe ".find_child_perf_for_time_period" do
    it "returns only tagged nodes" do
      ems_cluster
      expect(MetricRollup.count).to be > 0

      cols = %i(id name project provider_id)
      # :conditions => ["resource_type = ? and tag_names like ?", tag_klass, "%#{cat}/#{tag}%"]
      options = {:end_date => DateTime.current, :days => 30, :ext_options => {:time_profile => time_profile}}

      # currently, only vms have data, but only host data is returned
      results = VimPerformanceAnalysis.find_child_perf_for_time_period(ems, "daily", options)
      # expect(results).not_to be_empty
      VimPerformanceAnalysis.group_perf_by_timestamp(ems, results, cols)

      # for now, we're just content that it did not blow up
    end
  end

  # describe ".child_tags_over_time_period" do
  #   it "returns only tagged nodes" do
  #     good_vm = FactoryGirl.create(:vm_vmware, :tags => [tag_good])
  #     bad_vm  = FactoryGirl.create(:vm_vmware, :tags => [tag_bad])
  #   end
  # end

  describe ".get_daily_perf" do
    it "should not raise an error" do
      range       = {:days => 7, :end_date => "2016-04-19T23:00:00Z".to_time}
      ext_options = {:tz => "UTC", :time_profile => time_profile}
      perf_cols   = [:max_cpu_usagemhz_rate_average, :derived_cpu_available, :total_vcpus, :max_derived_memory_used, :derived_memory_available, :used_space, :total_space]
      expect { described_class.get_daily_perf(host1, range, ext_options, perf_cols).all.inspect }.not_to raise_error
    end
  end

  private

  def add_rollup(vm, timestamp, tag = tag_text)
    vm.metric_rollups << FactoryGirl.create(:metric_rollup_vm_daily, :with_data,
                                            :timestamp          => timestamp,
                                            :tag_names          => tag,
                                            :parent_host        => vm.host,
                                            :parent_ems_cluster => vm.ems_cluster,
                                            :parent_ems         => vm.ext_management_system,
                                            :parent_storage     => vm.storage,
                                            :resource_name      => vm.name,
                                            :time_profile       => time_profile,
                                           )
  end
end
