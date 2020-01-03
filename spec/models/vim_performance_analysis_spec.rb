RSpec.describe VimPerformanceAnalysis do
  let(:tag_text) { "operations/good" }
  let(:tag_good) { FactoryBot.create(:tag, :name => "/managed/#{tag_text}") }
  let(:tag_bad)  { FactoryBot.create(:tag, :name => "/managed/operations/bad") }
  let(:time_profile) { FactoryBot.create(:time_profile_with_rollup, :profile => {:tz => "UTC"}) }
  let(:ems) { FactoryBot.create(:ems_vmware) }

  let(:good_day) { DateTime.current - 2.day }
  let(:bad_day)  { DateTime.current - 4.months }
  let(:vm1) do
    FactoryBot.create(:vm_vmware, :name => "test_vm", :tags => [tag_good], :ext_management_system => ems).tap do |vm|
      [7, 8, 9, 10].each do |hour|
        add_rollup(vm, (good_day + hour.hours).to_s, tag_text)
        add_rollup(vm, (bad_day + hour.hours).to_s, tag_text)
      end
      vm.save!
    end
  end

  let(:storage) { FactoryBot.create(:storage_vmware) }
  let(:host1) do
    FactoryBot.create(:host,
                       :hardware => FactoryBot.create(:hardware,
                                                       :memory_mb       => 8124,
                                                       :cpu_total_cores => 1,
                                                       :cpu_speed       => 9576),
                       :vms      => [vm1],
                       :storages => [storage])
  end

  let(:ems_cluster) do
    FactoryBot.create(:ems_cluster, :ext_management_system => ems, :hosts => [host1])
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
      VimPerformanceAnalysis.group_perf_by_timestamp(ems, results, cols)

      # for now, we're just content that it did not blow up
    end
  end

  describe '.group_perf_by_timestamp' do
    let(:storage_metric) do
      FactoryBot.create(:metric_rollup,
                         :derived_storage_total => '42',
                         :derived_storage_free  => '13')
    end
    let(:cols) { [:derived_storage_total, :derived_storage_free, :v_derived_storage_used] }

    it 'does not pass virtual_attributes to MetricRollup.new' do
      expect(storage_metric.v_derived_storage_used).to eq(42 - 13)
      r = VimPerformanceAnalysis.group_perf_by_timestamp(ems, [storage_metric], cols)
      expect(r.length).to eq(1)
      expect(r[0]).to be_kind_of MetricRollup
      cols.each do |c|
        expect(r[0].send(c)).to eq(storage_metric.send(c))
      end
    end
  end

  describe ".get_daily_perf" do
    it "should not raise an error" do
      range       = {:days => 7, :end_date => "2016-04-19T23:00:00Z".to_time(:utc)}
      ext_options = {:tz => "UTC", :time_profile => time_profile}
      perf_cols   = [:max_cpu_usagemhz_rate_average, :derived_cpu_available, :total_vcpus, :max_derived_memory_used, :derived_memory_available, :used_space, :total_space]
      expect { described_class.get_daily_perf(host1, range, ext_options, perf_cols).all.inspect }.not_to raise_error
    end
  end

  private

  def add_rollup(vm, timestamp, tag = tag_text)
    vm.metric_rollups << FactoryBot.create(:metric_rollup_vm_daily, :with_data,
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
