RSpec.describe MiqReport::Generator do
  include Spec::Support::ChargebackHelper

  before do
    EvmSpecHelper.local_miq_server
    @user = FactoryBot.create(:user_with_group)
    @host1 = FactoryBot.create(:host)
  end

  describe "#generate" do
    context "Memory Utilization Trends report (daily)" do
      let(:start_date) { end_date - 4.days }
      let(:end_date) { Time.zone.yesterday.beginning_of_day }
      let(:time_profile_all) { FactoryBot.create(:time_profile_with_rollup, :tz => "UTC") }
      let(:metric_rollup_params) { {:derived_memory_available => 1400, :time_profile_id => time_profile_all.id} }

      before do
        @miq_report_profile_all = FactoryBot.create(
          :miq_report,
          :db              => "VimPerformanceTrend",
          :order           => "Ascending",
          :sortby          => ["resource_name"],
          :time_profile_id => time_profile_all.id,
          :db_options      => {:limit_col    => "max_derived_memory_available",
                               :trend_col    => "derived_memory_used",
                               :rpt_type     => "trend",
                               :start_offset => 604_800,
                               :end_offset   => 0,
                               :trend_db     => "HostPerformance",
                               :interval     => "daily",
                               :target_pcts  => [70, 80, 90]})
      end

      it "returns one row for each host" do
        used_mem_up = [400, 500, 600, 700]
        @host2 = FactoryBot.create(:host)
        add_metric_rollups_for([@host1, @host2], start_date...end_date, 1.day, metric_rollup_params, [], :metric_rollup_host_daily, :derived_memory_used => ->(x) { used_mem_up[x] })
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data.size).to eq(2)
      end

      it "calculates positive slope which is 'UP' trend" do
        used_mem_up = [400, 500, 600, 700]
        add_metric_rollups_for(@host1, start_date...end_date, 1.day, metric_rollup_params, [], :metric_rollup_host_daily, :derived_memory_used => ->(x) { used_mem_up[x] })
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data[0].data).to include("slope" => 100, "direction_of_trend" => "Up")
      end

      it "calculates negative slope which is 'Down' trend" do
        used_mem_down = [120, 90, 60, 30]
        add_metric_rollups_for(@host1, start_date...end_date, 1.day, metric_rollup_params, [], :metric_rollup_host_daily, :derived_memory_used => ->(x) { used_mem_down[x] })
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data[0].data).to include("slope" => -30, "direction_of_trend" => "Down")
      end

      it "calculates 0 slope which is 'Flat' trend" do
        used_mem_flat = [302, 300, 300, 302]
        add_metric_rollups_for(@host1, start_date...end_date, 1.day, metric_rollup_params, [], :metric_rollup_host_daily, :derived_memory_used => ->(x) { used_mem_flat[x] })
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data[0].data).to include("slope" => 0, "direction_of_trend" => "Flat")
      end

      it "calculates max and min trend values" do
        used_mem_up = [400, 500, 600, 700]
        add_metric_rollups_for(@host1, start_date...end_date, 1.day, metric_rollup_params, [], :metric_rollup_host_daily, :derived_memory_used => ->(x) { used_mem_up[x] })
        @miq_report_profile_all.generate_table(:userid => @user.userid)
        expect(@miq_report_profile_all.table.data[0].data).to include("min_trend_value" => 400,
                                                                      "max_trend_value" => 700)
      end

      it "handles merging WHERE clauses from MiqReport#where_clause and options[:where_clause]" do
        FactoryBot.create(:vm)       # filtered out by option[:where_clause]
        FactoryBot.create(:template) # filtered out by report.where_clause
        vm = FactoryBot.create(:vm, :vendor => "redhat")

        rpt = FactoryBot.create(
          :miq_report,
          :db           => "VmOrTemplate",
          :where_clause => ["vms.type = ?", "Vm"],
          :col_order    => %w[id name host.name vendor]
        )
        rpt.generate_table(:userid => @user.userid, :where_clause => {"vms.vendor" => "redhat"})

        expect(rpt.table.size).to eq(1)
        expect(rpt.table.first.id.to_s).to eq(vm.id.to_s)
      end
    end
  end

  describe "creates task, queue, audit event" do
    let(:report) do
      MiqReport.new(
        :name      => "Custom VM report",
        :title     => "Custom VM report",
        :rpt_group => "Custom",
        :rpt_type  => "Custom",
        :db        => "ManageIQ::Providers::InfraManager::Vm",
      )
    end

    before do
      User.seed
      EvmSpecHelper.local_miq_server
      ServerRole.seed
      expect(AuditEvent).to receive(:success)
    end

    it "#queue_generate_table" do
      report.queue_generate_table(:userid => "admin")
      task = MiqTask.first
      expect(task).to have_attributes(
        :name   => "Generate Report: '#{report.name}'",
        :userid => "admin"
      )

      message = MiqQueue.find_by(:method_name => "_async_generate_table")
      expect(message).to have_attributes(
        :role        => "reporting",
        :zone        => nil,
        :class_name  => report.class.name,
        :method_name => "_async_generate_table"
      )

      expect(message.args.first).to eq(task.id)
    end

    it "#queue_report_result" do
      task_id = report.queue_report_result({:userid => "admin"}, {})
      task = MiqTask.find(task_id)
      expect(task).to have_attributes(
        :name   => "Generate Report: '#{report.name}'",
        :userid => "admin"
      )

      message = MiqQueue.find_by(:method_name => "build_report_result")
      expect(message).to have_attributes(
        :role        => "reporting",
        :zone        => nil,
        :class_name  => report.class.name,
        :method_name => "build_report_result"
      )

      expect(message.args.first).to eq(task_id)
    end
  end

  describe "#cols_for_report" do
    it "uses cols" do
      rpt = MiqReport.new(:db => "VmOrTemplate", :cols => %w(vendor version name))
      expect(rpt.cols_for_report).to eq(%w(vendor version name))
    end

    it "uses include" do
      rpt = MiqReport.new(:db => "VmOrTemplate", :include => {"host" => { "columns" => %w(name hostname guid)}})
      expect(rpt.cols_for_report).to eq(%w(host.name host.hostname host.guid))
    end

    it "uses extra_cols" do
      rpt = MiqReport.new(:db => "VmOrTemplate")
      expect(rpt.cols_for_report(%w(vendor))).to eq(%w(vendor))
    end

    it "derives include" do
      rpt = MiqReport.new(:db => "VmOrTemplate", :cols => %w(vendor), :col_order =>%w(host.name vendor))
      expect(rpt.cols_for_report).to match_array(%w(vendor host.name))
    end

    it "works with col, col_order and include together" do
      rpt = MiqReport.new(:db        => "VmOrTemplate",
                          :cols      => %w(vendor),
                          :col_order => %w(host.name host.hostname vendor),
                          :include   => {"host" => { "columns" => %w(name hostname)}}
                         )
      expect(rpt.cols_for_report).to match_array(%w(vendor host.name host.hostname))
    end
  end

  describe "#get_include_for_find (private)" do
    it "returns nil with empty include" do
      rpt = MiqReport.new(:db      => "VmOrTemplate",
                          :include => {})
      expect(rpt.get_include_for_find).to be_nil
    end

    it "includes virtual_includes from virtual_attributes that are not sql friendly" do
      rpt = MiqReport.new(:db   => "VmOrTemplate",
                          :cols => %w(name platform))
      expect(rpt.get_include_for_find).to eq(:platform => {})
    end

    it "does not include sql friendly virtual_attributes" do
      rpt = MiqReport.new(:db   => "VmOrTemplate",
                          :cols => %w(name v_total_snapshots))
      expect(rpt.get_include_for_find).to be_nil
    end

    it "uses include and include_as_hash" do
      rpt = MiqReport.new(:db               => "VmOrTemplate",
                          :cols             => %w(name platform),
                          :include          => {:host => {:columns => %w(name)}, :storage => {:columns => %w(name)}},
                          :include_for_find => {:snapshots => {}})
      expect(rpt.get_include_for_find).to eq(:platform => {}, :host => {}, :storage => {}, :snapshots => {})
    end

    it "uses col, col_order, and virtual attributes and ignores empty include" do
      # it also allows cols to override col_order for requesting extra columns
      rpt = MiqReport.new(:db               => "VmOrTemplate",
                          :include          => {},
                          :cols             => %w[name v_datastore_path],
                          :col_order        => %w(name host.name storage.name),
                          :include_for_find => {:snapshots => {}})
      expect(rpt.get_include_for_find).to eq(:v_datastore_path => {}, :host => {}, :storage => {}, :snapshots => {})
    end

    it "uses col_order and virtual attributes" do
      rpt = MiqReport.new(:db               => "VmOrTemplate",
                          :include          => {},
                          :col_order        => %w[name v_datastore_path host.name storage.name],
                          :include_for_find => {:snapshots => {}})
      expect(rpt.get_include_for_find).to eq(:v_datastore_path => {}, :host => {}, :storage => {}, :snapshots => {})
    end
  end

  describe "#get_include (private)" do
    it "returns nil with empty include" do
      rpt = MiqReport.new(:db      => "VmOrTemplate",
                          :include => {})
      expect(rpt.get_include).to be_blank
    end

    it "includes virtual_includes from virtual_attributes that are not sql friendly" do
      rpt = MiqReport.new(:db   => "VmOrTemplate",
                          :cols => %w[name platform])
      expect(rpt.get_include).to eq(:platform => {})
    end

    it "does not include sql friendly virtual_attributes" do
      rpt = MiqReport.new(:db   => "VmOrTemplate",
                          :cols => %w[name v_total_snapshots])
      expect(rpt.get_include).to be_blank
    end

    it "uses include and include_as_hash" do
      rpt = MiqReport.new(:db               => "VmOrTemplate",
                          :cols             => %w[name platform],
                          :include          => {:host => {:columns => %w[name]}, :storage => {:columns => %w[name]}},
                          :include_for_find => {:snapshots => {}})
      expect(rpt.get_include).to eq(:platform => {}, :host => {}, :storage => {})
    end

    it "uses col, col_order, and virtual attributes and ignores empty include" do
      # it also allows cols to override col_order for requesting extra columns
      rpt = MiqReport.new(:db               => "VmOrTemplate",
                          :include          => {},
                          :cols             => %w[name v_datastore_path],
                          :col_order        => %w[name host.name storage.name],
                          :include_for_find => {:snapshots => {}})
      expect(rpt.get_include).to eq(:v_datastore_path => {}, :host => {}, :storage => {})
    end

    it "uses col_order and virtual attributes" do
      rpt = MiqReport.new(:db               => "VmOrTemplate",
                          :include          => {},
                          :col_order        => %w[name v_datastore_path host.name storage.name],
                          :include_for_find => {:snapshots => {}})
      expect(rpt.get_include).to eq(:v_datastore_path => {}, :host => {}, :storage => {})
    end
  end

  describe "sorting" do
    let(:vms)       { FactoryBot.create_list(:vm_vmware, 2) }
    let(:vm_amazon) { FactoryBot.create(:vm_amazon) }

    # nil values have special handling in sorting by forcing them to represent the maximum value from all values for the column
    it "handles sort columns with nil values properly, when column is string" do
      MiqReport.seed_report(name = "Vendor and Guest OS")
      vm = vms.first
      vm.update_attributes(:operating_system => FactoryBot.create(:operating_system, :name => "Linux", :product_name => "Linux"))

      expect(vm_amazon.operating_system).to be_nil

      rpt = MiqReport.where(:name => name).last

      rpt.generate_table(:userid => "test")
      report_result = rpt.build_create_results(:userid => "test")
      report_result.reload

      expect(report_result.report_results.table.data.first['vendor_display']).to eq(vm_amazon.vendor_display)
    end
  end
end
