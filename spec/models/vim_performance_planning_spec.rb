describe VimPerformancePlanning do
  context '.vm_how_many_more_can_fit' do
    let!(:local) { EvmSpecHelper.local_miq_server }
    let(:cluster) { FactoryGirl.create(:ems_cluster) }
    let(:compute_host) { FactoryGirl.create(:host, :ems_cluster => cluster) }
    let(:time_profile) { TimeProfile.seed }
    let!(:metrics) do
      FactoryGirl.create(:metric_rollup, :with_data,
                         :resource => compute_host, :capture_interval_name => 'daily', :time_profile => time_profile)
    end
    let(:options) do
      {:vm_options     => {:cpu     => {:value => nil, :mode => :manual},
                           :vcpus   => {:value => nil, :mode => :manual},
                           :memory  => {:value => 400, :mode => :manual},
                           :storage => {:value => nil, :mode => :manual}},
       :target_tags    => {:compute_type => :EmsCluster},
       :target_options => {:memory => {:mode => :perf_trend, :metric => :max_derived_memory_used,
                                      :limit_col => :derived_memory_available, :limit_pct => 90}},
       :range          => {:days => 7, :end_date => Time.current},
       :ext_options    => {:tz => 'UTC', :time_profile => time_profile}
      }
    end

    it 'calculates optimize/planning info for manually entered options' do
      perfs, opts = described_class.build_results_for_report_planning(options)
      expect(perfs.length).to eq(1)
      expect(perfs[0]).to be_kind_of(VimPerformancePlanning)
      expect(opts).to eq(:vm_profile => {:cpu => nil, :vcpus => nil, :memory => '400 MB', :storage => nil})
    end
  end
end
