RSpec.describe ChargebackVm do
  include Spec::Support::ChargebackHelper

  let(:admin) { FactoryBot.create(:user_admin) }
  let(:base_options) do
    {:interval_size       => 2,
     :end_interval_offset => 0,
     :tag                 => '/managed/environment/prod',
     :ext_options         => {:tz => 'UTC'},
     :userid              => admin.userid}
  end
  let(:hourly_rate)               { 0.01 }
  let(:count_hourly_rate)         { 1.00 }
  let(:cpu_count)                 { 1.0 }
  let(:memory_available)          { 1000.0 }
  let(:vm_allocated_disk_storage) { 4.0 }
  let(:starting_date) { Time.parse('2012-09-01 23:59:59Z').utc }
  let(:ts) { starting_date.in_time_zone(Metric::Helper.get_time_zone(base_options[:ext_options])) }
  let(:report_run_time) { month_end }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
  let(:ems) { FactoryBot.create(:ems_vmware) }

  let(:hourly_variable_tier_rate)       { {:variable_rate => hourly_rate.to_s} }
  let(:count_hourly_variable_tier_rate) { {:variable_rate => count_hourly_rate.to_s} }
  let(:fixed_compute_tier_rate)         { {:fixed_rate => hourly_rate.to_s} }

  let(:detail_params) do
    {
      :chargeback_rate_detail_cpu_used           => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_cpu_allocated      => {:tiers => [count_hourly_variable_tier_rate]},
      :chargeback_rate_detail_memory_allocated   => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_memory_used        => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_disk_io_used       => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_net_io_used        => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_storage_used       => {:tiers => [count_hourly_variable_tier_rate]},
      :chargeback_rate_detail_storage_allocated  => {:tiers => [count_hourly_variable_tier_rate]},
      :chargeback_rate_detail_fixed_compute_cost => {:tiers => [fixed_compute_tier_rate]}
    }
  end

  let!(:chargeback_rate) do
    FactoryBot.create(:chargeback_rate, :detail_params => detail_params)
  end

  let(:metric_rollup_params) do
    {
      :tag_names             => "environment/prod",
      :parent_host_id        => @host1.id,
      :parent_ems_cluster_id => @ems_cluster.id,
      :parent_ems_id         => ems.id,
      :parent_storage_id     => @storage.id,
    }
  end

  def pluck_rollup(metric_rollup_records)
    metric_rollup_records.pluck(*ChargeableField.cols_on_metric_rollup)
  end

  before do
    MiqRegion.seed
    ChargebackRateDetailMeasure.seed
    ChargeableField.seed
    ManageIQ::Showback::InputMeasure.seed
    MiqEnterprise.seed

    EvmSpecHelper.create_guid_miq_server_zone
    cat = FactoryBot.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryBot.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    @tag = Tag.find_by(:name => "/managed/environment/prod")

    temp = {:cb_rate => chargeback_rate, :tag => [c, "vm"]}
    ChargebackRate.set_assignments(:compute, [temp])

    Timecop.travel(report_run_time)
  end

  after do
    Timecop.return
  end

  context 'with metric rollups' do
    before do
      @vm1 = FactoryBot.create(:vm_vmware, :name => "test_vm", :evm_owner => admin, :ems_ref => "ems_ref",
                                :created_on => month_beginning)
      @vm1.tag_with(@tag.name, :ns => '*')

      @host1   = FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576), :vms => [@vm1])
      @storage = FactoryBot.create(:storage_vmware)
      @host1.storages << @storage

      @ems_cluster = FactoryBot.create(:ems_cluster, :ext_management_system => ems)
      @ems_cluster.hosts << @host1
    end

    let(:report_static_fields) { %w[vm_name] }

    it "uses static fields" do
      expect(described_class.report_static_cols).to match_array(report_static_fields)
    end

    it "succeeds without a userid" do
      options = base_options.except(:userid)
      expect { ChargebackVm.build_results_for_report_ChargebackVm(options) }.not_to raise_error
    end

    context "by service" do
      let(:options) { base_options.merge(:interval => 'monthly', :interval_size => 4, :service_id => @service.id) }
      before do
        @service = FactoryBot.create(:service)
        @service << @vm1
        @service.save

        @vm2 = FactoryBot.create(:vm_vmware, :name => "test_vm 2", :evm_owner => admin, :created_on => month_beginning)

        add_metric_rollups_for([@vm1, @vm2], month_beginning...month_end, 12.hours, metric_rollup_params)
      end

      it "only includes VMs belonging to service in results" do
        result = described_class.build_results_for_report_ChargebackVm(options)
        expect(result).not_to be_nil
        expect(result.first.all? { |r| r.vm_name == "test_vm" })
      end
    end

    context "Daily" do
      let(:hours_in_day) { 24 }
      let(:options) { base_options.merge(:interval => 'daily') }

      let(:start_time)  { report_run_time - 17.hours }
      let(:finish_time) { report_run_time - 14.hours }

      let(:cloud_volume) { FactoryBot.create(:cloud_volume_openstack) }

      it 'contains also columns with sub_metric(from cloud_volume)' do
        cloud_volume_type_chargeback_colums = []
        %w[metric cost].each do |key|
          cloud_volume_type_chargeback_colums << "storage_allocated_#{cloud_volume.volume_type}_#{key}"
        end

        described_class.refresh_dynamic_metric_columns

        expect(cloud_volume_type_chargeback_colums & described_class.attribute_names).to match_array(cloud_volume_type_chargeback_colums)
      end

      before do
        add_metric_rollups_for(@vm1, start_time...finish_time, 1.hour, metric_rollup_params)
      end

      context 'with cloud volume types' do
        let!(:cloud_volume_sdd) { FactoryBot.create(:cloud_volume_openstack, :volume_type => 'sdd') }
        let!(:cloud_volume_hdd) { FactoryBot.create(:cloud_volume_openstack, :volume_type => 'hdd') }
        let(:state_data) do
          {
            :allocated_disk_types => {
              'sdd' => 3.gigabytes,
              'hdd' => 1.gigabytes,
            },
          }
        end

        before do
          # create vim performance state
          allocated_storage_rate_detail = chargeback_rate.chargeback_rate_details.detect { |x| x.chargeable_field.metric == 'derived_vm_allocated_disk_storage' }
          CloudVolume.all.each do |cv|
            new_rate_detail = allocated_storage_rate_detail.dup
            new_rate_detail.sub_metric = cv.volume_type
            new_rate_detail.chargeback_tiers = allocated_storage_rate_detail.chargeback_tiers.map(&:dup)
            new_rate_detail.save
            chargeback_rate.chargeback_rate_details << new_rate_detail
          end

          chargeback_rate.save
          add_vim_performance_state_for(@vm1, start_time...finish_time, 1.hour, state_data)
        end

        it 'charges sub metrics as cloud volume types' do
          expect(subject.storage_allocated_sdd_metric).to eq(3.gigabytes)
          expect(subject.storage_allocated_sdd_cost).to eq(state_data[:allocated_disk_types]['sdd'] / 1.gigabytes * count_hourly_rate * hours_in_day)

          expect(subject.storage_allocated_hdd_metric).to eq(1.gigabytes)
          expect(subject.storage_allocated_hdd_cost).to eq(state_data[:allocated_disk_types]['hdd'] / 1.gigabytes * count_hourly_rate * hours_in_day)
        end

        it 'shows rates' do
          expect(subject.storage_allocated_sdd_rate).to eq("€1.00 / Hourly / GiB")
          expect(subject.storage_allocated_hdd_rate).to eq("€1.00 / Hourly / GiB")
        end

        it "doesn't return removed cloud volume types fields" do
          described_class.refresh_dynamic_metric_columns

          fields = described_class.attribute_names
          cloud_volume_hdd_field = "storage_allocated_#{cloud_volume_hdd.volume_type}_metric"
          expect(fields).to include(cloud_volume_hdd_field)

          cloud_volume_hdd.destroy

          described_class.current_volume_types_clear_cache
          described_class.refresh_dynamic_metric_columns
          fields = described_class.attribute_names
          expect(fields).not_to include(cloud_volume_hdd_field)
        end

        context 'without including metrics' do
          let(:ssd_volume_type) { 'ssd' }
          let(:ssd_size_1) { 1_234 }
          let!(:cloud_volume_1) { FactoryBot.create(:cloud_volume_openstack, :volume_type => ssd_volume_type, :size => ssd_size_1) }

          let(:ssd_disk_1) { FactoryBot.create(:disk, :size => ssd_size_1, :backing => cloud_volume_1) }

          let(:ssd_size_2) { 4_234 }
          let!(:cloud_volume_2) { FactoryBot.create(:cloud_volume_openstack, :volume_type => ssd_volume_type, :size => ssd_size_2) }

          let(:ssd_disk_2) { FactoryBot.create(:disk, :size => ssd_size_2, :backing => cloud_volume_2) }

          let(:hardware) { FactoryBot.create(:hardware, :disks => [ssd_disk_1, ssd_disk_2]) }

          let(:resource) { FactoryBot.create(:vm_vmware_cloud, :hardware => hardware, :created_on => month_beginning) }

          let(:storage_chargeback_rate) { FactoryBot.create(:chargeback_rate, :detail_params => detail_params, :rate_type => "Storage") }

          let(:parent_classification) { FactoryBot.create(:classification) }
          let(:classification)        { FactoryBot.create(:classification, :parent_id => parent_classification.id) }

          let(:rate_assignment_options) { {:cb_rate => storage_chargeback_rate, :object => MiqEnterprise.first } }
          let(:options) { base_options.merge(:interval => 'daily', :tag => nil, :entity_id => resource.id, :include_metrics => false) }

          before do
            # create rate detail for cloud volume
            allocated_storage_rate_detail = storage_chargeback_rate.chargeback_rate_details.detect { |x| x.chargeable_field.metric == 'derived_vm_allocated_disk_storage' }
            new_rate_detail = allocated_storage_rate_detail.dup
            new_rate_detail.sub_metric = ssd_volume_type
            new_rate_detail.chargeback_tiers = allocated_storage_rate_detail.chargeback_tiers.map(&:dup)
            new_rate_detail.save
            storage_chargeback_rate.chargeback_rate_details << new_rate_detail
            storage_chargeback_rate.save

            ChargebackRate.set_assignments(:storage, [rate_assignment_options])
          end

          it 'reports sub metric and costs' do
            expect(subject.storage_allocated_ssd_metric).to eq(ssd_size_1 + ssd_size_2)
          end
        end
      end

      subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

      context 'when the Vm resource of a consumption is destroyed' do
        let(:hours_in_day) { (finish_time.end_of_day - start_time) / 1.hour }

        before do
          @vm1.destroy
        end

        it "calculates allocated cpu cost and metric values" do
          expect(subject.cpu_allocated_metric).to eq(cpu_count)
          expect(subject.cpu_allocated_cost).to eq(cpu_count * count_hourly_rate * hours_in_day)
          expect(subject.cpu_cost).to eq(subject.cpu_allocated_cost + subject.cpu_used_cost)
        end
      end

      context 'when first metric rollup has tag_names=nil' do
        before do
          options[:tag] = nil
          options[:entity_id] = @vm1.id
          @vm1.metric_rollups.first.update(:tag_names => nil)
        end

        it "cpu" do
          expect(subject.cpu_allocated_metric).to eq(cpu_count)
          used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_day, @vm1)
          expect(subject.cpu_used_metric).to eq(used_metric)

          expect(subject.cpu_allocated_cost).to eq(cpu_count * count_hourly_rate * hours_in_day)
          expect(subject.cpu_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
          expect(subject.cpu_cost).to eq(subject.cpu_allocated_cost + subject.cpu_used_cost)
        end
      end

      it "cpu" do
        expect(subject.cpu_allocated_metric).to eq(cpu_count)
        used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_day, @vm1)
        expect(subject.cpu_used_metric).to eq(used_metric)

        expect(subject.cpu_allocated_cost).to eq(cpu_count * count_hourly_rate * hours_in_day)
        expect(subject.cpu_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
        expect(subject.cpu_cost).to eq(subject.cpu_allocated_cost + subject.cpu_used_cost)
      end

      it "reports Vm Guid" do
        expect(subject.vm_guid).to eq(@vm1.guid)
      end

      it "cpu_vm_and_cpu_container_project" do
        expect(subject.cpu_allocated_metric).to eq(cpu_count)
        used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_day, @vm1)
        expect(subject.cpu_used_metric).to eq(used_metric)

        expect(subject.cpu_allocated_cost).to eq(cpu_count * count_hourly_rate * hours_in_day)
        expect(subject.cpu_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
        expect(subject.cpu_cost).to eq(subject.cpu_allocated_cost + subject.cpu_used_cost)
      end

      it "memory" do
        expect(subject.memory_allocated_metric).to eq(memory_available)
        used_metric = used_average_for(:derived_memory_used, hours_in_day, @vm1)
        expect(subject.memory_used_metric).to eq(used_metric)

        expect(subject.memory_allocated_cost).to eq(memory_available * hourly_rate * hours_in_day)
        expect(subject.memory_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
        expect(subject.memory_cost).to eq(subject.memory_allocated_cost + subject.memory_used_cost)
      end

      it "disk io" do
        used_metric = used_average_for(:disk_usage_rate_average, hours_in_day, @vm1)
        expect(subject.disk_io_used_metric).to eq(used_metric)
        expect(subject.disk_io_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_day)
      end

      it "net io" do
        used_metric = used_average_for(:net_usage_rate_average, hours_in_day, @vm1)
        expect(subject.net_io_used_metric).to eq(used_metric)
        expect(subject.net_io_used_cost).to eq(used_metric * hourly_rate * hours_in_day)
      end

      it "storage" do
        used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_day, @vm1)
        expect(subject.storage_used_metric).to eq(used_metric)
        expect(subject.storage_used_cost).to eq(used_metric / 1.gigabyte * count_hourly_rate * hours_in_day)

        expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)
        storage_allocated_cost = vm_allocated_disk_storage * count_hourly_rate * hours_in_day
        expect(subject.storage_allocated_cost).to eq(storage_allocated_cost)

        expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
      end

      context "only memory_cost instead of all report columns" do
        let(:options) { base_options.merge(:interval => 'daily', :report_cols => %w[memory_cost]) }

        it "brings in relevant fields needed for calculation" do
          memory_allocated_cost = memory_available * hourly_rate * hours_in_day
          used_metric = used_average_for(:derived_memory_used, hours_in_day, @vm1)
          memory_used_cost = used_metric * hourly_rate * hours_in_day
          expect(subject.memory_cost).to eq(memory_allocated_cost + memory_used_cost)
        end
      end

      context "fixed rates" do
        let(:hourly_fixed_rate) { 10.0 }

        before do
          set_tier_param_for(:derived_vm_used_disk_storage, :fixed_rate, hourly_fixed_rate)
          set_tier_param_for(:derived_vm_allocated_disk_storage, :fixed_rate, hourly_fixed_rate)
          set_tier_param_for(:derived_vm_used_disk_storage, :variable_rate, 0.0)
          set_tier_param_for(:derived_vm_allocated_disk_storage, :variable_rate, 0.0)
        end

        it "storage metrics" do
          expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)
          used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_day, @vm1)
          expect(subject.storage_used_metric).to eq(used_metric)

          expected_value = hourly_fixed_rate * hours_in_day
          expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)

          expected_value = hourly_fixed_rate * hours_in_day
          expect(subject.storage_used_cost).to be_within(0.01).of(expected_value)
          expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
        end
      end
    end

    context "Report a chargeback of a tenant" do
      let(:options_tenant) { base_options.merge(:tenant_id => @tenant.id).tap { |t| t.delete(:tag) } }

      let(:start_time)  { report_run_time - 17.hours }
      let(:finish_time) { report_run_time - 14.hours }

      before do
        @tenant = FactoryBot.create(:tenant)
        @tenant_child = FactoryBot.create(:tenant, :parent => @tenant)
        @vm_tenant = FactoryBot.create(:vm_vmware, :tenant_id => @tenant_child.id,
                                        :name => "test_vm_tenant", :created_on => month_beginning)

        add_metric_rollups_for(@vm_tenant, start_time...finish_time, 1.hour, metric_rollup_params)
      end

      subject { ChargebackVm.build_results_for_report_ChargebackVm(options_tenant).first.first }

      it "report a chargeback of a subtenant" do
        expect(subject.vm_name).to eq(@vm_tenant.name)
      end
    end

    context "Monthly" do
      context "calculation of allocated metrics by average" do
        let(:start_time)  { report_run_time - 17.hours }
        let(:finish_time) { report_run_time - 14.hours }
        let(:options) { base_options.merge(:interval => 'monthly', :method_for_allocated_metrics => :avg) }

        before do
          mid_point = month_beginning + 10.days
          add_metric_rollups_for(@vm1, month_beginning...mid_point, 1.hour, metric_rollup_params)
          add_metric_rollups_for(@vm1, mid_point...month_end, 1.hour, metric_rollup_params.merge!(:derived_vm_numvcpus => 2))
        end

        subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

        it "calculates cpu allocated metric" do
          expect(subject.cpu_allocated_metric).to eq(1.6666666666666667)
          expect(subject.cpu_allocated_cost).to eq(1200) # ?
        end
      end

      context "current month and previous month" do
        let(:options) { base_options.merge(:interval => 'monthly') }
        let(:finish_time) { Time.current }
        let(:finish_time_formatted) { finish_time.strftime('%m/%d/%Y') }
        let(:report_start) { month_end + 2.days }
        subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first }

        let(:first_month_beginning) { month_beginning }
        let(:first_month_beginning_formatted) { first_month_beginning.strftime('%m/%d/%Y') }
        let(:second_month_beginning) { month_beginning + 1.month }
        let(:second_month_beginning_formatted) { second_month_beginning.strftime('%m/%d/%Y') }

        before do
          Timecop.travel(report_start)
          @vm1.update(:retires_on => finish_time)
          add_metric_rollups_for(@vm1, month_beginning...finish_time, 8.hours, metric_rollup_params)
        end

        it "reports report interval range and report generation date" do
          # reporting of first month
          report_range = "#{first_month_beginning_formatted} - #{second_month_beginning_formatted}"
          expect(subject.first.report_interval_range).to eq(report_range)
          expect(subject.first.report_generation_date.strftime('%m/%d/%Y')).to eq(finish_time_formatted)

          # reporting of second month
          report_range = "#{second_month_beginning_formatted} - #{(second_month_beginning + 2.days).strftime('%m/%d/%Y')}"
          expect(subject.second.report_interval_range).to eq(report_range)
          expect(subject.second.report_generation_date.strftime('%m/%d/%Y')).to eq(finish_time_formatted)
        end
      end
    end

    context 'monthly report, group by tenants' do
      let(:options) do
        {
          :interval                     => "monthly",
          :interval_size                => 12,
          :end_interval_offset          => 1,
          :tenant_id                    => tenant_1.id,
          :method_for_allocated_metrics => 'max',
          :include_metrics              => true,
          :groupby                      => "tenant",
        }
      end

      let(:monthly_used_rate)      { hourly_rate * hours_in_month }
      let(:monthly_allocated_rate) { count_hourly_rate * hours_in_month }

      # My Company
      #   \___Tenant 2
      #   \___Tenant 3
      #     \__Tenant 4
      #     \__Tenant 5
      #
      let(:tenant_1) { Tenant.root_tenant }
      let(:vm_1_1)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_1, :miq_group => nil) }
      let(:vm_2_1)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_1, :miq_group => nil) }

      let(:tenant_2) { FactoryBot.create(:tenant, :name => 'Tenant 2', :parent => tenant_1) }
      let(:vm_1_2)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_2, :miq_group => nil) }
      let(:vm_2_2)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_2, :miq_group => nil) }

      let(:tenant_3) { FactoryBot.create(:tenant, :name => 'Tenant 3', :parent => tenant_1) }
      let(:vm_1_3)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_3, :miq_group => nil) }
      let(:vm_2_3)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_3, :miq_group => nil) }

      let(:tenant_4) { FactoryBot.create(:tenant, :name => 'Tenant 4', :divisible => false, :parent => tenant_3) }
      let(:vm_1_4)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_4, :miq_group => nil) }
      let(:vm_2_4)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_4, :miq_group => nil) }

      let(:tenant_5) { FactoryBot.create(:tenant, :name => 'Tenant 5', :divisible => false, :parent => tenant_3) }
      let(:vm_1_5)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_5, :miq_group => nil) }
      let(:vm_2_5)   { FactoryBot.create(:vm_vmware, :created_on => month_beginning, :tenant => tenant_5, :miq_group => nil) }

      subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first }

      let(:derived_vm_numvcpus_tenant_5) { 1 }
      let(:cpu_usagemhz_rate_average_tenant_5) { 50 }

      before do
        add_metric_rollups_for([vm_1_1, vm_2_1], month_beginning...month_end, 8.hours, metric_rollup_params.merge!(:derived_vm_numvcpus => 1, :cpu_usagemhz_rate_average => 50))
        add_metric_rollups_for([vm_1_2, vm_2_2], month_beginning...month_end, 8.hours, metric_rollup_params.merge!(:derived_vm_numvcpus => 1, :cpu_usagemhz_rate_average => 50))
        add_metric_rollups_for([vm_1_3, vm_2_3], month_beginning...month_end, 8.hours, metric_rollup_params.merge!(:derived_vm_numvcpus => 1, :cpu_usagemhz_rate_average => 50))
        add_metric_rollups_for([vm_1_4, vm_2_4], month_beginning...month_end, 8.hours, metric_rollup_params.merge!(:derived_vm_numvcpus => 1, :cpu_usagemhz_rate_average => 50))
        add_metric_rollups_for([vm_1_5, vm_2_5], month_beginning...month_end, 8.hours, metric_rollup_params.merge!(:derived_vm_numvcpus => derived_vm_numvcpus_tenant_5, :cpu_usagemhz_rate_average => cpu_usagemhz_rate_average_tenant_5))
      end

      it 'reports each tenants' do
        expect(subject.map(&:tenant_name)).to match_array([tenant_1, tenant_2, tenant_3, tenant_4, tenant_5].map(&:name))
      end

      def subject_row_for_tenant(tenant)
        subject.detect { |x| x.tenant_name == tenant.name }
      end

      let(:hourly_usage) { 30 * 3.0 / 720 } # count of metric rollups / hours in month

      it 'calculates allocated,used metric with using max,avg method with vcpus=1.0 and 50% usage' do
        # sum of maxes from each VM:
        # (max from first tenant_1's VM +  max from second tenant_1's VM) * monthly_allocated_rate
        expect(subject_row_for_tenant(tenant_1).cpu_allocated_metric).to eq(1 + 1)
        expect(subject_row_for_tenant(tenant_1).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

        expect(subject_row_for_tenant(tenant_2).cpu_allocated_metric).to eq(1 + 1)
        expect(subject_row_for_tenant(tenant_2).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

        expect(subject_row_for_tenant(tenant_3).cpu_allocated_metric).to eq(1 + 1)
        expect(subject_row_for_tenant(tenant_3).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

        expect(subject_row_for_tenant(tenant_4).cpu_allocated_metric).to eq(1 + 1)
        expect(subject_row_for_tenant(tenant_4).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

        expect(subject_row_for_tenant(tenant_5).cpu_allocated_metric).to eq(1 + 1)
        expect(subject_row_for_tenant(tenant_5).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

        # each tenant has 2 VMs and each VM  has 50 of cpu usage:
        # 5 tenants(tenant_1 has 4 tenants and plus tenant_1 ) * 2 VMs * 50% of usage
        expect(subject_row_for_tenant(tenant_1).cpu_used_metric).to eq(2 * 50 * hourly_usage)
        # and cost - there is multiplication by monthly_used_rate
        expect(subject_row_for_tenant(tenant_1).cpu_used_cost).to eq(2 * 50 * hourly_usage * monthly_used_rate)

        expect(subject_row_for_tenant(tenant_2).cpu_used_metric).to eq(2 * 50 * hourly_usage)
        expect(subject_row_for_tenant(tenant_2).cpu_used_cost).to eq(2 * 50 * hourly_usage * monthly_used_rate)

        expect(subject_row_for_tenant(tenant_3).cpu_used_metric).to eq(2 * 50 * hourly_usage)
        expect(subject_row_for_tenant(tenant_3).cpu_used_cost).to eq(2 * 50 * hourly_usage * monthly_used_rate)

        expect(subject_row_for_tenant(tenant_4).cpu_used_metric).to eq(2 * 50 * hourly_usage)
        expect(subject_row_for_tenant(tenant_4).cpu_used_cost).to eq(2 * 50 * hourly_usage * monthly_used_rate)

        expect(subject_row_for_tenant(tenant_5).cpu_used_metric).to eq(2 * 50 * hourly_usage)
        expect(subject_row_for_tenant(tenant_5).cpu_used_cost).to eq(2 * 50 * hourly_usage * monthly_used_rate)
      end

      context 'vcpu=5 for VMs of tenant_5' do
        let(:derived_vm_numvcpus_tenant_5)       { 5 }
        let(:cpu_usagemhz_rate_average_tenant_5) { 75 }

        it 'calculates allocated,used metric with using max,avg method with vcpus=1.0 and 50% usage' do
          expect(subject_row_for_tenant(tenant_1).cpu_allocated_metric).to eq(1 + 1)
          expect(subject_row_for_tenant(tenant_1).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

          expect(subject_row_for_tenant(tenant_2).cpu_allocated_metric).to eq(1 + 1)
          expect(subject_row_for_tenant(tenant_2).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

          expect(subject_row_for_tenant(tenant_3).cpu_allocated_metric).to eq(1 + 1)
          expect(subject_row_for_tenant(tenant_3).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

          expect(subject_row_for_tenant(tenant_4).cpu_allocated_metric).to eq(1 + 1)
          expect(subject_row_for_tenant(tenant_4).cpu_allocated_cost).to eq((1 + 1) * monthly_allocated_rate)

          expect(subject_row_for_tenant(tenant_5).cpu_allocated_metric).to eq(5 + 5)
          expect(subject_row_for_tenant(tenant_5).cpu_allocated_cost).to eq((5 + 5) * monthly_allocated_rate)

          # each tenant has 2 VMs and each VM  has 50 of cpu usage:
          # 5 tenants(tenant_1 has 4 tenants and plus tenant_1 ) * 2 VMs * 50% of usage
          # but tenant_5 has  2 VMs and each VM  has 75 of cpu usage
          expect(subject_row_for_tenant(tenant_1).cpu_used_metric).to eq(hourly_usage * 2 * 50)
          # and cost - there is multiplication by  monthly_used_rate
          expect(subject_row_for_tenant(tenant_1).cpu_used_cost).to eq(hourly_usage * 2 * 50 * monthly_used_rate)

          expect(subject_row_for_tenant(tenant_2).cpu_used_metric).to eq(hourly_usage * 2 * 50)
          expect(subject_row_for_tenant(tenant_2).cpu_used_cost).to eq(hourly_usage * 2 * 50 * monthly_used_rate)

          expect(subject_row_for_tenant(tenant_3).cpu_used_metric).to eq(hourly_usage * 2 * 50)
          expect(subject_row_for_tenant(tenant_3).cpu_used_cost).to eq(hourly_usage * 2 * 50 * monthly_used_rate)

          expect(subject_row_for_tenant(tenant_4).cpu_used_metric).to eq(hourly_usage * 2 * 50)
          expect(subject_row_for_tenant(tenant_4).cpu_used_cost).to eq(hourly_usage * 2 * 50 * monthly_used_rate)

          expect(subject_row_for_tenant(tenant_5).cpu_used_metric).to eq(hourly_usage * 2 * 75)
          expect(subject_row_for_tenant(tenant_5).cpu_used_cost).to eq(hourly_usage * 2 * 75 * monthly_used_rate)
        end

        context 'test against group by vm report' do
          let(:options_group_vm) do
            {
              :interval                     => "monthly",
              :interval_size                => 12,
              :end_interval_offset          => 1,
              :tenant_id                    => tenant_1.id,
              :method_for_allocated_metrics => :max,
              :include_metrics              => true,
              :groupby                      => "vm"
            }
          end

          def result_row_for_vm(vm)
            result_group_by_vm.detect { |x| x.vm_name == vm.name }
          end

          let(:result_group_by_vm) { ChargebackVm.build_results_for_report_ChargebackVm(options_group_vm).first }

          it 'calculates used metric and cost same as report for each vm' do
            # Tenant 1 VMs
            all_vms_cpu_metric = [vm_1_1, vm_2_1].map { |vm| result_row_for_vm(vm).cpu_used_metric }.sum
            all_vms_cpu_cost   = [vm_1_1, vm_2_1].map { |vm| result_row_for_vm(vm).cpu_used_cost }.sum

            # Tenant 1
            expect(subject_row_for_tenant(tenant_1).cpu_used_metric).to eq(all_vms_cpu_metric)
            expect(subject_row_for_tenant(tenant_1).cpu_used_cost).to eq(all_vms_cpu_cost)

            # Tenant 5 Vms
            result_vm15 = result_row_for_vm(vm_1_5)
            result_vm25 = result_row_for_vm(vm_2_5)

            expect(subject_row_for_tenant(tenant_5).cpu_used_metric).to eq(result_vm15.cpu_used_metric + result_vm25.cpu_used_metric)
            expect(subject_row_for_tenant(tenant_5).cpu_used_cost).to eq(result_vm15.cpu_used_cost + result_vm25.cpu_used_cost)
          end

          it 'calculated allocted metric and cost with using max(max is not summed up - it is taken maximum)' do
            # Tenant 1 VMs
            all_vms_cpu_metric = [vm_1_1, vm_2_1].map { |vm| result_row_for_vm(vm).cpu_allocated_metric }.sum
            all_vms_cpu_cost   = [vm_1_1, vm_2_1].map { |vm| result_row_for_vm(vm).cpu_allocated_cost }.sum

            expect(subject_row_for_tenant(tenant_1).cpu_allocated_metric).to eq(all_vms_cpu_metric)
            expect(subject_row_for_tenant(tenant_1).cpu_allocated_cost).to eq(all_vms_cpu_cost)
          end
        end

        context 'test against group by date-only report' do
          let(:options_group_date_only) do
            {
              :interval                     => "daily",
              :interval_size                => 7,
              :end_interval_offset          => 0,
              :tenant_id                    => tenant_5.id,
              :method_for_allocated_metrics => :max,
              :include_metrics              => true,
              :groupby                      => "date-only"
            }
          end

          let(:options_group_date) do
            {
              :interval                     => "daily",
              :interval_size                => 7,
              :end_interval_offset          => 0,
              :tenant_id                    => tenant_5.id,
              :method_for_allocated_metrics => :max,
              :include_metrics              => true,
              :groupby                      => "date"
            }
          end

          let(:result_group_by_date_only) { ChargebackVm.build_results_for_report_ChargebackVm(options_group_date_only).first }
          let(:result_group_by_date)      { ChargebackVm.build_results_for_report_ChargebackVm(options_group_date).first }

          def result_row_by(chargeback_result, date)
            chargeback_result.select { |x| x.display_range == date }
          end

          it 'is grouping values per date' do
            ((month_end - 5.days)..month_end).step_value(1.day) do |display_range|
              display_range = display_range.strftime('%m/%d/%Y')
              rs1 = result_row_by(result_group_by_date_only, display_range)
              rs2 = result_row_by(result_group_by_date, display_range)

              %w[cpu_allocated_metric
                 cpu_allocated_cost
                 cpu_used_metric
                 cpu_used_cost
                 disk_io_used_metric
                 disk_io_used_cost
                 fixed_compute_metric
                 fixed_compute_1_cost
                 memory_allocated_metric
                 memory_allocated_cost
                 net_io_used_metric
                 net_io_used_cost
                 storage_allocated_metric
                 storage_allocated_cost
                 storage_used_metric
                 storage_used_cost].each { |field| expect(rs2.map { |x| x.send(field) }.sum).to eq(rs1.map { |x| x.send(field) }.sum) }
            end
          end
        end
      end
    end

    context "Monthly" do
      let(:options) { base_options.merge(:interval => 'monthly') }
      before do
        add_metric_rollups_for(@vm1, month_beginning...month_end, 12.hours, metric_rollup_params)
      end

      subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

      context "when MetricRollup#tag_names are not considered" do
        before do
          # report filter is set to different tag
          @vm1.metric_rollups.each { |mr| mr.update(:tag_names => 'registered/no|folder_path_yellow/datacenters') }
        end

        it "cpu" do
          expect(subject.cpu_allocated_metric).to eq(cpu_count)
          used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month, @vm1)
          expect(subject.cpu_used_metric).to be_within(0.01).of(used_metric)
          expect(subject.cpu_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
          expect(subject.cpu_allocated_cost).to be_within(0.01).of(cpu_count * count_hourly_rate * hours_in_month)
        end
      end

      context "chargeback rate contains rate unrelated to chargeback vm" do
        let!(:chargeback_rate) do
          FactoryBot.create(:chargeback_rate, :detail_params => detail_params.merge(:chargeback_rate_detail_cpu_cores_allocated => {:tiers => [count_hourly_variable_tier_rate]}))
        end

        it "skips unrelated columns and calculate related columns" do
          expect(subject.cpu_allocated_metric).to eq(cpu_count)
        end
      end

      it "cpu" do
        expect(subject.cpu_allocated_metric).to eq(cpu_count)
        used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month, @vm1)
        expect(subject.cpu_used_metric).to be_within(0.01).of(used_metric)
        expect(subject.cpu_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
        expect(subject.cpu_allocated_cost).to be_within(0.01).of(cpu_count * count_hourly_rate * hours_in_month)
      end

      context 'with nonzero fixed rate' do
        let(:hourly_variable_tier_rate) { {:fixed_rate => 100, :variable_rate => hourly_rate.to_s} }

        it 'shows rates' do
          expect(subject.cpu_allocated_rate).to eq("€1.00 / Hourly / Cpu")
          expect(subject.cpu_used_rate).to eq("€100.00 / Hourly + €0.01 / Hourly / MHz")
          expect(subject.disk_io_used_rate).to eq("€100.00 / Hourly + €0.01 / Hourly / Mbps")
          expect(subject.fixed_compute_1_rate).to eq("€0.01 / Hourly")
          expect(subject.memory_allocated_rate).to eq("€100.00 / Hourly + €0.01 / Hourly / MiB")
          expect(subject.memory_used_rate).to eq("€100.00 / Hourly + €0.01 / Hourly / MiB")
          expect(subject.net_io_used_rate).to eq("€100.00 / Hourly + €0.01 / Hourly / Mbps")
          expect(subject.storage_allocated_rate).to eq("€1.00 / Hourly / GiB")
          expect(subject.storage_used_rate).to eq("€1.00 / Hourly / GiB")
        end
      end

      let(:fixed_rate) { 10.0 }

      context "fixed and variable rate" do
        before do
          set_tier_param_for(:derived_vm_numvcpus, :fixed_rate, fixed_rate)
          set_tier_param_for(:cpu_usagemhz_rate_average, :fixed_rate, fixed_rate)
        end

        it "cpu" do
          expect(subject.cpu_allocated_metric).to eq(cpu_count)
          used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month, @vm1)
          expect(subject.cpu_used_metric).to be_within(0.01).of(used_metric)

          fixed = fixed_rate * hours_in_month
          variable = cpu_count * count_hourly_rate * hours_in_month
          expect(subject.cpu_allocated_cost).to be_within(0.01).of(fixed + variable)

          fixed = fixed_rate * hours_in_month
          variable = used_metric * hourly_rate * hours_in_month
          expect(subject.cpu_used_cost).to be_within(0.01).of(fixed + variable)
        end
      end

      it "memory" do
        expect(subject.memory_allocated_metric).to eq(memory_available)
        used_metric = used_average_for(:derived_memory_used, hours_in_month, @vm1)
        expect(subject.memory_used_metric).to be_within(0.01).of(used_metric)

        memory_allocated_cost = memory_available * hourly_rate * hours_in_month
        expect(subject.memory_allocated_cost).to be_within(0.01).of(memory_allocated_cost)
        expect(subject.memory_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
        expect(subject.memory_cost).to eq(subject.memory_allocated_cost + subject.memory_used_cost)
      end

      it "disk io" do
        used_metric = used_average_for(:disk_usage_rate_average, hours_in_month, @vm1)
        expect(subject.disk_io_used_metric).to be_within(0.01).of(used_metric)
        expect(subject.disk_io_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
      end

      it "net io" do
        used_metric = used_average_for(:net_usage_rate_average, hours_in_month, @vm1)
        expect(subject.net_io_used_metric).to be_within(0.01).of(used_metric)
        expect(subject.net_io_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
      end

      context "fixed rates" do
        let(:hourly_fixed_rate) { 10.0 }

        before do
          set_tier_param_for(:derived_vm_used_disk_storage, :fixed_rate, hourly_fixed_rate)
          set_tier_param_for(:derived_vm_allocated_disk_storage, :fixed_rate, hourly_fixed_rate)

          set_tier_param_for(:derived_vm_used_disk_storage, :variable_rate, 0.0)
          set_tier_param_for(:derived_vm_allocated_disk_storage, :variable_rate, 0.0)
        end

        it "storage with only fixed rates" do
          expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)
          used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_month, @vm1)
          expect(subject.storage_used_metric).to be_within(0.01).of(used_metric)

          expected_value = hourly_fixed_rate * hours_in_month
          expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)

          expected_value = hourly_fixed_rate * hours_in_month
          expect(subject.storage_used_cost).to be_within(0.01).of(expected_value)
          expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
        end
      end

      it "storage" do
        expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)
        used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_month, @vm1)
        expect(subject.storage_used_metric).to be_within(0.01).of(used_metric)

        expected_value = vm_allocated_disk_storage * count_hourly_rate * hours_in_month
        expect(subject.storage_allocated_cost).to be_within(0.01).of(expected_value)
        expected_value = used_metric / 1.gigabytes * count_hourly_rate * hours_in_month
        expect(subject.storage_used_cost).to be_within(0.01).of(expected_value)
        expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
      end

      context "by owner" do
        let(:user) { FactoryBot.create(:user, :name => 'Test VM Owner', :userid => 'test_user') }
        let(:options) { {:interval_size => 4, :owner => user.userid, :ext_options => {:tz => 'Eastern Time (US & Canada)'} } }
        before do
          @vm1.update_attribute(:evm_owner, user)
        end

        it "valid" do
          expect(subject.owner_name).to eq(user.name)
        end

        it "not exist" do
          user.delete
          expect { subject }.to raise_error(MiqException::Error, "Unable to find user '#{user.userid}'")
        end
      end
    end

    describe "#get_rates" do
      let(:chargeback_rate)         { FactoryBot.create(:chargeback_rate, :rate_type => "Compute") }
      let(:chargeback_vm)           { ChargebackVm.new }
      let(:rate_assignment_options) { {:cb_rate => chargeback_rate, :object => Tenant.root_tenant} }
      let(:metric_rollup) do
        FactoryBot.create(:metric_rollup_vm_hr, :timestamp => report_run_time - 1.day - 17.hours,
                           :tag_names => "environment/prod",
                           :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                           :parent_ems_id => ems.id, :parent_storage_id => @storage.id,
                           :resource => @vm1)
      end
      let(:consumption) { Chargeback::ConsumptionWithRollups.new(pluck_rollup([metric_rollup]), nil, nil) }

      before do
        ChargebackRate.set_assignments(:compute, [rate_assignment_options])
        @rate = Chargeback::RatesCache.new(Chargeback::ReportOptions.new_from_h(base_options)).get(consumption).first
        @assigned_rate = ChargebackRate.get_assignments("Compute").first
      end

      it "return tenant chargeback detail rate" do
        expect(@rate).not_to be_nil
        expect(@rate.id).to eq(@assigned_rate[:cb_rate].id)
      end

      context "selecting based on tagged cloud volumes" do
        let!(:cloud_volume_sdd) { FactoryBot.create(:cloud_volume_openstack, :volume_type => 'sdd') }

        let(:ssd_size) { 1_234 }
        let(:ssd_disk) { FactoryBot.create(:disk, :size => ssd_size, :backing => cloud_volume_sdd) }
        let(:hardware) { FactoryBot.create(:hardware, :disks => [ssd_disk]) }

        let(:resource) { FactoryBot.create(:vm_vmware_cloud, :hardware => hardware, :created_on => month_beginning) }

        let(:consumption) { Chargeback::ConsumptionWithoutRollups.new(resource, nil, nil) }

        let(:storage_chargeback_rate) { FactoryBot.create(:chargeback_rate, :rate_type => "Storage") }

        let(:parent_classification) { FactoryBot.create(:classification) }
        let(:classification)        { FactoryBot.create(:classification, :parent_id => parent_classification.id) }

        let(:rate_assignment_options) { {:cb_rate => storage_chargeback_rate, :tag => [classification, "storage"]} }

        subject { Chargeback::RatesCache.new(Chargeback::ReportOptions.new_from_h(base_options)).get(consumption).first }

        before do
          ChargebackRate.set_assignments(:storage, [rate_assignment_options])
        end

        it "chooses rate according to cloud_volume\'s tag" do
          cloud_volume_sdd.tag_with([classification.tag.name], :ns => '*')

          expect(subject).to eq(storage_chargeback_rate)
        end

        it "doesn't choose rate thanks to missing tag on cloud_volume" do
          expect(subject).to be_nil
        end
      end
    end

    describe '.report_row_key' do
      let(:report_options) { Chargeback::ReportOptions.new }
      let(:timestamp_key) { 'Fri, 13 May 2016 10:40:00 UTC +00:00' }
      let(:beginning_of_day) { timestamp_key.in_time_zone.beginning_of_day }
      let(:metric_rollup) { FactoryBot.create(:metric_rollup_vm_hr, :timestamp => timestamp_key, :resource => @vm1) }
      let(:consumption) { Chargeback::ConsumptionWithRollups.new(pluck_rollup([metric_rollup]), nil, nil) }
      subject { described_class.report_row_key(consumption) }
      before do
        described_class.instance_variable_set(:@options, report_options)
      end

      it { is_expected.to eq("#{metric_rollup.resource_id}_#{beginning_of_day}") }
    end

    describe '#initialize' do
      let(:report_options) { Chargeback::ReportOptions.new }
      let(:vm_owners)     { {@vm1.id => @vm1.evm_owner_name} }
      let(:consumption) { Chargeback::ConsumptionWithRollups.new(pluck_rollup([metric_rollup]), nil, nil) }
      let(:shared_extra_fields) do
        {'vm_name' => @vm1.name, 'owner_name' => admin.name, 'vm_uid' => 'ems_ref', 'vm_guid' => @vm1.guid,
         'vm_id' => @vm1.id}
      end
      subject { ChargebackVm.new(report_options, consumption, MiqRegion.my_region_number).attributes }

      before do
        ChargebackVm.instance_variable_set(:@vm_owners, vm_owners)
      end

      context 'with parent ems' do
        let(:metric_rollup) do
          FactoryBot.create(:metric_rollup_vm_hr, :tag_names => 'environment/prod',
                            :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                            :parent_ems_id => ems.id, :parent_storage_id => @storage.id,
                            :resource => @vm1, :resource_name => @vm1.name)
        end

        it 'sets extra fields' do
          is_expected.to include(shared_extra_fields.merge('provider_name' => ems.name, 'provider_uid' => ems.guid))
        end
      end

      context 'when parent ems is missing' do
        let(:metric_rollup) do
          FactoryBot.create(:metric_rollup_vm_hr, :tag_names => 'environment/prod',
                            :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                            :parent_storage_id => @storage.id,
                            :resource => @vm1, :resource_name => @vm1.name)
        end

        it 'sets extra fields when parent ems is missing' do
          is_expected.to include(shared_extra_fields.merge('provider_name' => nil, 'provider_uid' => nil))
        end
      end
    end

    context 'cumulative chargeback' do
      let(:options) do
        base_options[:tag] = nil
        base_options[:entity_id] = vm.id
        base_options[:cumulative_rate_calculation] = true
        base_options[:interval] = 'monthly'
        base_options
      end

      let(:vm) { FactoryBot.create(:vm_vmware, :evm_owner => admin, :name => "vm_1", :created_on => month_beginning) }

      let(:parent_classification_1)   { FactoryBot.create(:classification, :name => 'department') }
      let(:classification_1_1)        { FactoryBot.create(:classification, :name => 'financial', :parent_id => parent_classification_1.id) }

      let(:parent_classification_2)   { FactoryBot.create(:classification, :name => 'enviroment') }
      let(:classification_2_1)        { FactoryBot.create(:classification, :name => 'test', :parent_id => parent_classification_2.id) }

      let(:hourly_rate_2)       { 0.05 }
      let(:count_hourly_rate_2) { 10.00 }

      let(:hourly_variable_tier_rate_2)       { {:variable_rate => hourly_rate_2.to_s} }
      let(:count_hourly_variable_tier_rate_2) { {:variable_rate => count_hourly_rate_2.to_s} }

      let(:fixed_hourly_variable_tier_rate_2) { {:fixed_rate    => count_hourly_rate_2.to_s} }

      let(:detail_params_2) do
        {
          :chargeback_rate_detail_cpu_used           => {:tiers => [hourly_variable_tier_rate_2]},
          :chargeback_rate_detail_cpu_allocated      => {:tiers => [count_hourly_variable_tier_rate_2]},
          :chargeback_rate_detail_memory_allocated   => {:tiers => [hourly_variable_tier_rate_2]},
          :chargeback_rate_detail_memory_used        => {:tiers => [hourly_variable_tier_rate_2]},
          :chargeback_rate_detail_disk_io_used       => {:tiers => [hourly_variable_tier_rate_2]},
          :chargeback_rate_detail_net_io_used        => {:tiers => [hourly_variable_tier_rate_2]},
          :chargeback_rate_detail_storage_used       => {:tiers => [count_hourly_variable_tier_rate_2]},
          :chargeback_rate_detail_storage_allocated  => {:tiers => [count_hourly_variable_tier_rate_2]},
          :chargeback_rate_detail_fixed_compute_cost => {:tiers => [fixed_hourly_variable_tier_rate_2]}
        }
      end

      let(:chargeback_rate_1) { FactoryBot.create(:chargeback_rate, :rate_type => "Compute", :detail_params => detail_params) }
      let(:chargeback_rate_2) { FactoryBot.create(:chargeback_rate, :rate_type => "Compute", :detail_params => detail_params_2) }

      let(:rates) do
        [
          {:cb_rate => chargeback_rate_1, :tag => [classification_1_1, "vm"]},
          {:cb_rate => chargeback_rate_2, :tag => [classification_2_1, "vm"]}
        ]
      end

      before do
        # fix fixed computes cost tier - we are not using variable part
        detail_params[:chargeback_rate_detail_fixed_compute_cost][:tiers] = [{:fixed_rate => count_hourly_rate.to_s }]

        vm.tag_with([classification_1_1.tag.name, classification_2_1.tag.name], :ns => '*')

        metric_rollup_params[:tag_names] = rates.map { |rate| rate[:tag].first.tag.send(:name_path) }.join('|')
        add_metric_rollups_for(vm, month_beginning...month_end, 12.hours, metric_rollup_params)

        ChargebackRate.set_assignments(:compute, rates)
      end

      subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

      it 'calculates accumulations' do
        descriptions = [chargeback_rate_1.description, chargeback_rate_2.description].sort
        expect(subject.chargeback_rates).to eq(descriptions.join(", "))

        # fixed
        expect(subject.fixed_compute_metric).to eq(vm.metric_rollups.count)

        fixed_cost1 = hours_in_month * count_hourly_rate
        fixed_cost2 = hours_in_month * count_hourly_rate_2
        expect(subject.fixed_compute_1_cost).to eq(fixed_cost1 + fixed_cost2)

        # cpu
        expect(subject.cpu_allocated_metric).to eq(cpu_count)

        cpu_cost_rate1 = cpu_count * count_hourly_rate * hours_in_month
        cpu_cost_rate2 = cpu_count * count_hourly_rate_2 * hours_in_month
        expect(subject.cpu_allocated_cost).to eq(cpu_cost_rate1 + cpu_cost_rate2)

        used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month, vm)

        expect(subject.cpu_used_metric).to eq(used_metric)

        cpu_cost_rate1 = used_metric * hourly_rate * hours_in_month
        cpu_cost_rate2 = used_metric * hourly_rate_2 * hours_in_month
        expect(subject.cpu_used_cost).to eq(cpu_cost_rate1 + cpu_cost_rate2)

        expect(subject.cpu_cost).to eq(subject.cpu_allocated_cost + subject.cpu_used_cost)

        # memory
        expect(subject.memory_allocated_metric).to eq(memory_available)

        memory_cost_rate1 = memory_available * hourly_rate * hours_in_month
        memory_cost_rate2 = memory_available * hourly_rate_2 * hours_in_month
        expect(subject.memory_allocated_cost).to eq(memory_cost_rate1 + memory_cost_rate2)

        used_metric = used_average_for(:derived_memory_used, hours_in_month, vm)
        expect(subject.memory_used_metric).to eq(used_metric)

        memory_cost_rate1 = used_metric * hourly_rate * hours_in_month
        memory_cost_rate2 = used_metric * hourly_rate_2 * hours_in_month

        expect(subject.memory_used_cost).to eq(memory_cost_rate1 + memory_cost_rate2)
        expect(subject.memory_cost).to eq(subject.memory_allocated_cost + subject.memory_used_cost)

        used_metric = used_average_for(:disk_usage_rate_average, hours_in_month, vm)
        expect(subject.disk_io_used_metric).to eq(used_metric)

        # disk io
        disk_io_cost_rate1 = used_metric * hourly_rate * hours_in_month
        disk_io_cost_rate2 = used_metric * hourly_rate_2 * hours_in_month
        expect(subject.disk_io_used_cost).to eq(disk_io_cost_rate1 + disk_io_cost_rate2)

        used_metric = used_average_for(:net_usage_rate_average, hours_in_month, vm)
        expect(subject.net_io_used_metric).to eq(used_metric)

        # net io
        net_io_cost_rate1 = used_metric * hourly_rate * hours_in_month
        net_io_cost_rate2 = used_metric * hourly_rate_2 * hours_in_month
        expect(subject.net_io_used_cost).to eq(net_io_cost_rate1 + net_io_cost_rate2)

        expect(subject.storage_allocated_metric).to eq(vm_allocated_disk_storage.gigabytes)

        # storage
        storage_cost_rate1 = vm_allocated_disk_storage * count_hourly_rate * hours_in_month
        storage_cost_rate2 = vm_allocated_disk_storage * count_hourly_rate_2 * hours_in_month
        expect(subject.storage_allocated_cost).to eq(storage_cost_rate1 + storage_cost_rate2)

        used_metric = used_average_for(:derived_vm_used_disk_storage, hours_in_month, vm)
        expect(subject.storage_used_metric).to eq(used_metric)
        storage_cost_rate1 = used_metric / 1.gigabytes * count_hourly_rate * hours_in_month
        storage_cost_rate2 = used_metric / 1.gigabytes * count_hourly_rate_2 * hours_in_month

        expect(subject.storage_used_cost).to be_within(0.01).of(storage_cost_rate1 + storage_cost_rate2)
        expect(subject.storage_cost).to eq(subject.storage_allocated_cost + subject.storage_used_cost)
      end

      context 'with fixed part for second chargeback rates' do
        let(:fixed_rate)                  { 100 }
        let(:hourly_variable_tier_rate_2) { {:variable_rate => hourly_rate_2.to_s, :fixed_rate => fixed_rate.to_s} }

        it 'calculates accumulations' do
          # memory
          expect(subject.memory_allocated_metric).to eq(memory_available)

          memory_cost_rate1 = memory_available * hourly_rate * hours_in_month
          memory_cost_rate2 = fixed_rate * hours_in_month + memory_available * hourly_rate_2 * hours_in_month

          expect(subject.memory_allocated_cost).to eq(memory_cost_rate1 + memory_cost_rate2)

          used_metric = used_average_for(:derived_memory_used, hours_in_month, vm)
          expect(subject.memory_used_metric).to eq(used_metric)

          memory_cost_rate1 = used_metric * hourly_rate * hours_in_month
          memory_cost_rate2 = fixed_rate * hours_in_month + used_metric * hourly_rate_2 * hours_in_month

          expect(subject.memory_used_cost).to eq(memory_cost_rate1 + memory_cost_rate2)
          expect(subject.memory_cost).to eq(subject.memory_allocated_cost + subject.memory_used_cost)

          used_metric = used_average_for(:disk_usage_rate_average, hours_in_month, vm)
          expect(subject.disk_io_used_metric).to eq(used_metric)
        end
      end
    end

    context 'more rates have been selected' do
      let(:storage_chargeback_rate_1) { FactoryBot.create(:chargeback_rate, :rate_type => "Storage") }
      let(:storage_chargeback_rate_2) { FactoryBot.create(:chargeback_rate, :rate_type => "Storage") }
      let(:chargeback_vm)             { Chargeback::RatesCache.new(Chargeback::ReportOptions.new_from_h(base_options)) }

      let(:parent_classification) { FactoryBot.create(:classification) }
      let(:classification_1)      { FactoryBot.create(:classification, :parent_id => parent_classification.id) }
      let(:classification_2)      { FactoryBot.create(:classification, :parent_id => parent_classification.id) }

      let(:rate_assignment_options_1) { {:cb_rate => storage_chargeback_rate_1, :tag => [classification_1, "Storage"]} }
      let(:rate_assignment_options_2) { {:cb_rate => storage_chargeback_rate_2, :tag => [classification_2, "Storage"]} }

      let(:metric_rollup) do
        FactoryBot.create(:metric_rollup_vm_hr, :timestamp => report_run_time - 1.day - 17.hours,
                           :parent_host_id => @host1.id, :parent_ems_cluster_id => @ems_cluster.id,
                           :parent_ems_id => ems.id, :parent_storage_id => @storage.id,
                           :resource => @vm)
      end

      before do
        @storage.tag_with([classification_1.tag.name, classification_2.tag.name], :ns => '*')
        ChargebackRate.set_assignments(:storage, [rate_assignment_options_1, rate_assignment_options_2])
        @vm = FactoryBot.create(:vm_vmware, :name => "test_vm_1", :evm_owner => admin, :ems_ref => "ems_ref", :created_on => month_beginning)
      end

      it "return only one chargeback rate according to tag name of Vm" do
        [rate_assignment_options_1, rate_assignment_options_2].each do |rate_assignment|
          metric_rollup.update!(:tag_names => rate_assignment[:tag].first.tag.send(:name_path))
          @vm.tag_with(["/managed/#{metric_rollup.tag_names}"], :ns => '*')
          @vm.reload
          consumption = Chargeback::ConsumptionWithRollups.new(pluck_rollup([metric_rollup]), nil, nil)
          uniq_rates = Chargeback::RatesCache.new(Chargeback::ReportOptions.new_from_h(base_options)).get(consumption)
          consumption.instance_variable_set(:@tag_names, nil)
          consumption.instance_variable_set(:@hash_features_affecting_rate, nil)
          expect([rate_assignment[:cb_rate]]).to match_array(uniq_rates)
        end
      end
    end

    context "Group by tags" do
      let(:options) { base_options.merge(:interval => 'monthly', :groupby_tag => 'environment') }
      before do
        add_metric_rollups_for(@vm1, month_beginning...month_end, 12.hours, metric_rollup_params)
      end

      subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

      context "with global and remote regions" do
        let(:options_tenant)  { base_options.merge(:interval => 'monthly', :tenant_id => tenant_1.id).tap { |t| t.delete(:tag) } }
        let(:vm_global)       { FactoryBot.create(:vm_vmware) }
        let!(:region_1) { FactoryBot.create(:miq_region) }

        def find_result_by_vm_name_and_region(chargeback_result, vm_name, region)
          first_region_id, last_region_id = MiqRegion.region_to_array(region)

          chargeback_result.detect do |result|
            result.vm_name == vm_name && result.vm_id.between?(first_region_id, last_region_id)
          end
        end

        let(:tenant_name_1) { "T1" }
        let(:tenant_name_2) { "T2" }
        let(:tenant_name_3) { "T3" }

        let(:vm_name_1) { "VM 1 T1" }

        # BUILD tenants and VMs structure for default region
        #
        # T1(vm_1, vm_2) ->
        #   T2(vm_1, vm_2)
        #   T3(vm_1, vm_2)
        let!(:tenant_1) { FactoryBot.create(:tenant, :parent => Tenant.root_tenant, :name => tenant_name_1, :description => tenant_name_1) }
        let(:vm_1_t_1) { FactoryBot.create(:vm_vmware, :tenant => tenant_1, :name => vm_name_1) }
        let(:vm_2_t_1) { FactoryBot.create(:vm_vmware, :tenant => tenant_1) }

        let(:tenant_2) { FactoryBot.create(:tenant, :name => tenant_name_2, :parent => tenant_1, :description => tenant_name_2) }
        let(:vm_1_t_2) { FactoryBot.create(:vm_vmware, :tenant => tenant_2) }
        let(:vm_2_t_2) { FactoryBot.create(:vm_vmware, :tenant => tenant_2) }

        let(:tenant_3) { FactoryBot.create(:tenant, :name => tenant_name_3, :parent => tenant_1, :description => tenant_name_3) }
        let(:vm_1_t_3) { FactoryBot.create(:vm_vmware, :tenant => tenant_3) }
        let(:vm_2_t_3) { FactoryBot.create(:vm_vmware, :tenant => tenant_3) }

        # BUILD tenants and VMs structure for region_1
        #
        # T1(vm_1, vm_2) ->
        #   T2(vm_1, vm_2)
        #   T3(vm_1, vm_2)
        #
        let!(:root_tenant_region_1) do
          tenant_other_region = FactoryGirl.create(:tenant, :in_other_region, :other_region => region_1)
          tenant_other_region.update_attribute(:parent, nil) # rubocop:disable Rails/SkipsModelValidations
          tenant_other_region
        end

        let!(:tenant_1_region_1) { FactoryBot.create(:tenant, :in_other_region, :other_region => region_1, :name => tenant_name_1, :parent => root_tenant_region_1, :description => tenant_name_1) }
        let(:vm_1_region_1_t_1) { FactoryBot.create(:vm_vmware, :in_other_region, :other_region => region_1, :tenant => tenant_1_region_1, :name => vm_name_1) }
        let(:vm_2_region_1_t_1) { FactoryBot.create(:vm_vmware, :in_other_region, :other_region => region_1, :tenant => tenant_1_region_1) }

        let!(:tenant_2_region_1) { FactoryBot.create(:tenant, :in_other_region, :other_region => region_1, :name => tenant_name_2, :parent => tenant_1_region_1, :description => tenant_name_2) }
        let(:vm_1_region_1_t_2) { FactoryBot.create(:vm_vmware, :in_other_region, :other_region => region_1, :tenant => tenant_2_region_1) }
        let(:vm_2_region_1_t_2) { FactoryBot.create(:vm_vmware, :in_other_region, :other_region => region_1, :tenant => tenant_2_region_1) }

        let!(:tenant_3_region_1) { FactoryBot.create(:tenant, :in_other_region, :other_region => region_1, :name => tenant_name_3, :parent => tenant_1_region_1, :description => tenant_name_3) }
        let(:vm_1_region_1_t_3) { FactoryBot.create(:vm_vmware, :in_other_region, :other_region => region_1, :tenant => tenant_3_region_1) }
        let(:vm_2_region_1_t_3) { FactoryBot.create(:vm_vmware, :in_other_region, :other_region => region_1, :tenant => tenant_3_region_1) }

        before do
          # default region
          add_metric_rollups_for(vm_1_t_1, month_beginning...month_end, 12.hours, metric_rollup_params)
          add_metric_rollups_for(vm_2_t_1, month_beginning...month_end, 12.hours, metric_rollup_params)
          add_metric_rollups_for(vm_1_t_2, month_beginning...month_end, 12.hours, metric_rollup_params)
          add_metric_rollups_for(vm_2_t_2, month_beginning...month_end, 12.hours, metric_rollup_params)
          add_metric_rollups_for(vm_1_t_3, month_beginning...month_end, 12.hours, metric_rollup_params)
          add_metric_rollups_for(vm_2_t_3, month_beginning...month_end, 12.hours, metric_rollup_params)

          metric_rollup_params_with_other_region = metric_rollup_params
          metric_rollup_params_with_other_region[:other_region] = region_1
          # region 1
          add_metric_rollups_for(vm_1_region_1_t_1, month_beginning...month_end, 12.hours, metric_rollup_params_with_other_region, %i[with_data in_other_region])
          add_metric_rollups_for(vm_2_region_1_t_1, month_beginning...month_end, 12.hours, metric_rollup_params_with_other_region, %i[with_data in_other_region])
          add_metric_rollups_for(vm_1_region_1_t_2, month_beginning...month_end, 12.hours, metric_rollup_params_with_other_region, %i[with_data in_other_region])
          add_metric_rollups_for(vm_2_region_1_t_2, month_beginning...month_end, 12.hours, metric_rollup_params_with_other_region, %i[with_data in_other_region])
          add_metric_rollups_for(vm_1_region_1_t_3, month_beginning...month_end, 12.hours, metric_rollup_params_with_other_region, %i[with_data in_other_region])
          add_metric_rollups_for(vm_2_region_1_t_3, month_beginning...month_end, 12.hours, metric_rollup_params_with_other_region, %i[with_data in_other_region])
        end

        subject! { ChargebackVm.build_results_for_report_ChargebackVm(options_tenant).first }

        context "tenants don't exist" do
          let(:unknown_number) { 999_999_999 }
          let(:options_with_tenant_only_in_default_region) { base_options.merge(:interval => 'monthly', :tenant_id => tenant_default_region.id).tap { |t| t.delete(:tag) } }
          let!(:tenant_default_region) { FactoryBot.create(:tenant, :parent => Tenant.root_tenant) }

          it "generates empty result and doesn't raise error" do
            exception_message = "Unable to find tenant '#{tenant_default_region.name}' (based on tenant id '#{tenant_default_region.id}' from default region) in region #{region_1.region}."

            log_stub = instance_double("_log")
            expect(described_class).to receive(:_log).and_return(log_stub).at_least(:once)

            expect(log_stub).to receive(:debug).with(any_args).at_least(:once)
            expect(log_stub).to receive(:info).with(exception_message + " Calculating chargeback costs skipped for #{tenant_default_region.id} in region #{region_1.region}.").at_least(:once)
            expect(log_stub).to receive(:info).with(any_args).at_least(:once)
            expect(ChargebackVm.build_results_for_report_ChargebackVm(options_with_tenant_only_in_default_region).flatten).to be_empty
          end

          context "tenant in default region doesn't exists" do
            let(:options_with_missing_tenant) { base_options.merge(:interval => 'monthly', :tenant_id => unknown_number).tap { |t| t.delete(:tag) } }

            it "generates empty result and doesn't raise error" do
              exception_message = "Unable to find tenant '#{unknown_number}'."

              log_stub = instance_double("_log")
              expect(described_class).to receive(:_log).and_return(log_stub).at_least(:once)

              expect(log_stub).to receive(:debug).with(any_args).at_least(:once)
              expect(log_stub).to receive(:info).with(exception_message + " Calculating chargeback costs skipped for #{unknown_number} in region #{region_1.region}.").at_least(:once)
              expect(log_stub).to receive(:info).with(any_args).at_least(:once)

              expect(ChargebackVm.build_results_for_report_ChargebackVm(options_with_missing_tenant).flatten).to be_empty
            end
          end
        end

        it "report from all regions and only for tenant_1" do
          # report only VMs from tenant 1
          vm_ids = subject.map(&:vm_id)
          vm_ids_from_tenant = [tenant_1, tenant_1_region_1].map { |t| t.subtree.map(&:vms).map(&:ids) }.flatten
          expect(vm_ids).to match_array(vm_ids_from_tenant)

          # default region subject
          default_region_chargeback = find_result_by_vm_name_and_region(subject, vm_name_1, MiqRegion.my_region_number)
          used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month, vm_1_t_1)
          expect(default_region_chargeback.cpu_used_metric).to be_within(0.01).of(used_metric)
          expect(default_region_chargeback.cpu_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
          expect(default_region_chargeback.cpu_allocated_cost).to be_within(0.01).of(cpu_count * count_hourly_rate * hours_in_month)
          expect(default_region_chargeback.cpu_allocated_metric).to eq(cpu_count)

          # region 1
          region_1_chargeback = find_result_by_vm_name_and_region(subject, vm_name_1, region_1.region)
          used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month, vm_1_region_1_t_1)
          expect(region_1_chargeback.cpu_used_metric).to be_within(0.01).of(used_metric)
          expect(region_1_chargeback.cpu_used_cost).to be_within(0.01).of(used_metric * hourly_rate * hours_in_month)
          expect(region_1_chargeback.cpu_allocated_cost).to be_within(0.01).of(cpu_count * count_hourly_rate * hours_in_month)

          expect(region_1_chargeback.vm_id).to eq(vm_1_region_1_t_1.id)
        end
      end

      it "cpu" do
        expect(subject.cpu_allocated_metric).to eq(cpu_count)
        used_metric = used_average_for(:cpu_usagemhz_rate_average, hours_in_month, @vm1)
        expect(subject.cpu_used_metric).to be_within(0.01).of(used_metric)
        expect(subject.tag_name).to eq('Production')
      end
    end
  end

  context 'without metric rollups' do
    let(:cores)               { 7 }
    let(:mem_mb)              { 1777 }
    let(:disk_gb)             { 7 }
    let(:disk_b)              { disk_gb * 1024**3 }

    let(:hardware) do
      FactoryBot.create(:hardware,
                        :cpu_total_cores => cores,
                        :memory_mb       => mem_mb,
                        :disks           => [FactoryBot.create(:disk, :size => disk_b)])
    end

    let(:fixed_cost) { hourly_rate * 24 }
    let(:mem_cost) { mem_mb * hourly_rate * 24 }
    let(:cpu_cost) { cores * count_hourly_rate * 24 }
    let(:disk_cost) { disk_gb * count_hourly_rate * 24 }

    context 'for SCVMM (hyper-v)' do
      let!(:vm1) do
        vm = FactoryBot.create(:vm_microsoft, :hardware => hardware, :created_on => report_run_time - 1.day)
        vm.tag_with(@tag.name, :ns => '*')
        vm
      end

      let(:options) { base_options.merge(:interval => 'daily') }

      subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

      it 'fixed compute is calculated properly' do
        expect(subject.chargeback_rates).to eq(chargeback_rate.description)
        expect(subject.fixed_compute_metric).to eq(1) # One day of fixed compute metric
        expect(subject.fixed_compute_1_cost).to eq(fixed_cost)
      end

      it 'allocated metrics are calculated properly' do
        expect(subject.memory_allocated_metric).to  eq(mem_mb)
        expect(subject.memory_allocated_cost).to    eq(mem_cost)
        expect(subject.cpu_allocated_metric).to     eq(cores)
        expect(subject.cpu_allocated_cost).to       eq(cpu_cost)
        expect(subject.storage_allocated_metric).to eq(disk_b)
        expect(subject.storage_allocated_cost).to   eq(disk_cost)
        expect(subject.total_cost).to               eq(fixed_cost + cpu_cost + mem_cost + disk_cost)
      end
    end

    context 'for any virtual machine' do
      let!(:vm1) do
        vm = FactoryBot.create(:vm_vmware, :hardware => hardware, :created_on => report_run_time - 1.day)
        vm.tag_with(@tag.name, :ns => '*')
        vm
      end

      subject { ChargebackVm.build_results_for_report_ChargebackVm(options).first.first }

      let(:options) { base_options.merge(:interval => 'daily', :include_metrics => false) }

      it 'fixed compute is calculated properly' do
        expect(subject.chargeback_rates).to eq(chargeback_rate.description)
        expect(subject.fixed_compute_metric).to eq(1) # One day of fixed compute metric
        expect(subject.fixed_compute_1_cost).to eq(fixed_cost)
      end

      it 'metrics are calculated properly' do
        expect(subject.memory_allocated_metric).to  eq(mem_mb)
        expect(subject.memory_allocated_cost).to    eq(mem_cost)
        expect(subject.cpu_allocated_metric).to     eq(cores)
        expect(subject.cpu_allocated_cost).to       eq(cpu_cost)
        expect(subject.storage_allocated_metric).to eq(disk_b)
        expect(subject.storage_allocated_cost).to   eq(disk_cost)

        expect(subject.total_cost).to               eq(fixed_cost + cpu_cost + mem_cost + disk_cost)
      end

      context 'metrics are included (but dont have any)' do
        it 'is not generating report with options[:include_metrics]=true' do
          options[:include_metrics] = true
          expect(subject).to be_nil
        end

        it 'is not generating report with options[:include_metrics]=nil(default value)' do
          options[:include_metrics] = nil
          expect(subject).to be_nil
        end
      end
    end
  end
end
