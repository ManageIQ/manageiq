RSpec.describe BottleneckEvent do
  describe ".future_event_definitions_for_obj" do
    it "contains things" do
      MiqEventDefinition.seed_default_definitions(MiqEventDefinition.all.group_by(&:name))
      expect(BottleneckEvent.future_event_definitions_for_obj(ManageIQ::Providers::Vmware::InfraManager::Host.new)).not_to be_empty
    end
  end

  describe ".event_where_clause" do
    it "queries enterprises" do
      ent = FactoryBot.create(:miq_enterprise)
      query = described_class.event_where_clause(ent)
      expect(query).to match(/resource_type = 'MiqEnterprise'/)
    end

    it "queries enterprises with ems" do
      ent = FactoryBot.create(:miq_enterprise)
      FactoryBot.create(:ext_management_system)
      query = described_class.event_where_clause(ent)
      expect(query).to match(/resource_type = 'MiqEnterprise'.*resource_type = 'ExtManagementSystem'/)
    end

    it "queries enterprises with storage" do
      ent = FactoryBot.create(:miq_enterprise)
      FactoryBot.create(:storage)
      query = described_class.event_where_clause(ent)
      expect(query).to match(/resource_type = 'MiqEnterprise'.*resource_type = 'Storage'/)
    end

    it "queries regions" do
      reg = FactoryBot.create(:miq_region)
      query = described_class.event_where_clause(reg)
      expect(query).to match(/resource_type = 'MiqRegion'/)
    end

    it "queries regions with ems" do
      reg = FactoryBot.create(:miq_region)
      FactoryBot.create(:ext_management_system)
      query = described_class.event_where_clause(reg)
      expect(query).to match(/resource_type = 'MiqRegion'.*resource_type = 'ExtManagementSystem'/)
    end

    it "queries regions with storage" do
      reg = FactoryBot.create(:miq_region)
      FactoryBot.create(:storage)
      query = described_class.event_where_clause(reg)
      expect(query).to match(/resource_type = 'MiqRegion'.*resource_type = 'Storage'/)
    end

    it "queries ems" do
      ems = FactoryBot.create(:ext_management_system)
      query = described_class.event_where_clause(ems)
      expect(query).to match(/resource_type = 'ExtManagementSystem'/)
    end

    it "queries ems with cluster" do
      ems = FactoryBot.create(:ext_management_system)
      FactoryBot.create(:ems_cluster, :ext_management_system => ems)
      query = described_class.event_where_clause(ems)
      expect(query).to match(/resource_type = 'ExtManagementSystem'.*resource_type = 'EmsCluster'/)
    end

    it "queries ems with host" do
      ems = FactoryBot.create(:ext_management_system)
      FactoryBot.create(:host, :ext_management_system => ems)
      query = described_class.event_where_clause(ems)
      expect(query).to match(/resource_type = 'ExtManagementSystem'.*resource_type = 'Host'/)
    end

    it "queries cluster with host" do
      cluster = FactoryBot.create(:ems_cluster)
      FactoryBot.create(:host, :ems_cluster => cluster)
      query = described_class.event_where_clause(cluster)
      expect(query).to match(/resource_type = 'EmsCluster'.*resource_type = 'Host'/)
    end
  end

  describe ".last_created_on" do
    subject { described_class.last_created_on(resource) }
    let(:resource) { FactoryBot.create(resource_name) }
    let!(:bottleneck_event) { BottleneckEvent.create!(:resource => resource) }

    context "for a host_redhat resource" do
      let(:resource_name) { :host_redhat }
      it { is_expected.to be_within(0.1).of bottleneck_event.created_on }
    end

    context "for a host_vmware resource" do
      let(:resource_name) { :host_vmware }
      it { is_expected.to be_within(0.1).of bottleneck_event.created_on }
    end

    context "for a miq_enterprise resource" do
      let(:resource_name) { :miq_enterprise }
      it { is_expected.to be_within(0.1).of bottleneck_event.created_on }
    end

    context "for a ems_redhat resource" do
      let(:resource_name) { :ems_redhat }
      it { is_expected.to be_within(0.1).of bottleneck_event.created_on }
    end

    context "for a ems_cluster_openstack resource" do
      let(:resource_name) { :ems_cluster_openstack }
      it { is_expected.to be_within(0.1).of bottleneck_event.created_on }
    end
  end

  describe ".delete_future_events_for_obj" do
    let(:resource) { FactoryBot.create(resource_name) }
    let!(:bottleneck_event) { BottleneckEvent.create!(:resource => resource, :future => true) }

    before { BottleneckEvent.delete_future_events_for_obj(resource) }

    context "for a host_redhat resource" do
      let(:resource_name) { :host_redhat }
      it "deletes the future event" do
        expect(bottleneck_event).to be_deleted
      end
    end

    context "for a host_vmware resource" do
      let(:resource_name) { :host_vmware }
      it "deletes the future event" do
        expect(bottleneck_event).to be_deleted
      end
    end

    context "for a miq_enterprise resource" do
      let(:resource_name) { :miq_enterprise }
      it "deletes the future event" do
        expect(bottleneck_event).to be_deleted
      end
    end

    context "for a ems_cluster_openstack resource" do
      let(:resource_name) { :ems_cluster_openstack }
      it "deletes the future event" do
        expect(bottleneck_event).to be_deleted
      end
    end
  end

  describe ".generate_future_events" do
    before do
      EvmSpecHelper.local_miq_server
      MiqEventDefinition.seed_default_definitions(MiqEventDefinition.all.group_by(&:name))
    end

    let(:resource) { FactoryBot.create(:host_vmware) }
    let(:time_profile) { FactoryBot.create(:time_profile_utc) }

    it "generates CpuUsage projections" do
      # Generate 30 days of metrics with a gently rising slope
      30.times do |i|
        FactoryBot.create(:metric_rollup_host_daily,
          :resource     => resource,
          :timestamp    => i.days.ago.beginning_of_day,
          :time_profile => time_profile,
          :min_max      => {
            :max_cpu_usagemhz_rate_average => 3_000 - i * 100,
            :max_derived_cpu_available     => 5_000
          }
        )
      end

      described_class.generate_future_events(resource)

      events = described_class.order(:id).to_a
      expect(events).to match_array([
        have_attributes(
          :timestamp  => be_within(0.01).of(20.days.from_now.beginning_of_day),
          :resource   => resource,
          :event_type => "CpuUsage",
          :severity   => 1,
          :future     => true,
          :message    => "CPU - Peak Usage Rate for Collected Intervals (MHz) is projected to reach 5 GHz (100% of CPU Max Total MHz)"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(15.days.from_now.beginning_of_day),
          :resource   => resource,
          :event_type => "CpuUsage",
          :severity   => 1,
          :future     => true,
          :message    => "CPU - Peak Usage Rate for Collected Intervals (MHz) is projected to reach 4.5 GHz (90% of CPU Max Total MHz)"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(7.days.from_now.middle_of_day),
          :resource   => resource,
          :event_type => "CpuUsage",
          :severity   => 2,
          :future     => true,
          :message    => "CPU - Peak Usage Rate for Collected Intervals (MHz) is projected to reach 3.8 GHz (75% of CPU Max Total MHz)"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(5.days.ago.beginning_of_day),
          :resource   => resource,
          :event_type => "CpuUsage",
          :severity   => 3,
          :future     => true,
          :message    => "CPU - Peak Usage Rate for Collected Intervals (MHz) is projected to reach 2.5 GHz (50% of CPU Max Total MHz)"
        )
      ])
    end

    it "generates MemoryUsage projections" do
      # Generate 30 days of metrics with a gently rising slope
      30.times do |i|
        FactoryBot.create(:metric_rollup_host_daily,
          :resource     => resource,
          :timestamp    => i.days.ago.beginning_of_day,
          :time_profile => time_profile,
          :min_max      => {
            :max_derived_memory_used      => 300_000 - i * 10_000,
            :max_derived_memory_available => 500_000
          }
        )
      end

      described_class.generate_future_events(resource)

      events = described_class.order(:id).to_a
      expect(events).to match_array([
        have_attributes(
          :timestamp  => be_within(0.01).of(20.days.from_now.beginning_of_day),
          :resource   => resource,
          :event_type => "MemoryUsage",
          :severity   => 1,
          :future     => true,
          :message    => "Memory - Peak Aggregate Used for Child VMs for Collected Intervals (MB) is projected to reach 488.3 GB (100% of Memory Max Total)"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(15.days.from_now.beginning_of_day),
          :resource   => resource,
          :event_type => "MemoryUsage",
          :severity   => 1,
          :future     => true,
          :message    => "Memory - Peak Aggregate Used for Child VMs for Collected Intervals (MB) is projected to reach 439.5 GB (90% of Memory Max Total)"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(7.days.from_now.middle_of_day),
          :resource   => resource,
          :event_type => "MemoryUsage",
          :severity   => 2,
          :future     => true,
          :message    => "Memory - Peak Aggregate Used for Child VMs for Collected Intervals (MB) is projected to reach 366.2 GB (75% of Memory Max Total)"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(5.days.ago.beginning_of_day),
          :resource   => resource,
          :event_type => "MemoryUsage",
          :severity   => 3,
          :future     => true,
          :message    => "Memory - Peak Aggregate Used for Child VMs for Collected Intervals (MB) is projected to reach 244.1 GB (50% of Memory Max Total)"
        )
      ])
    end

    it "generates DiskUsage projections" do
      # Generate 30 days of metrics with a gently rising slope
      30.times do |i|
        FactoryBot.create(:metric_rollup_host_daily,
          :resource     => resource,
          :timestamp    => i.days.ago.beginning_of_day,
          :time_profile => time_profile,
          :derived_storage_total => 500_000_000_000,
          :derived_storage_free => 500_000_000_000 - (300_000_000_000 - i * 10_000_000_000)
        )
        FactoryBot.create(:metric_rollup_host_hr,
          :resource     => resource,
          :timestamp    => i.days.ago.beginning_of_day,
          :time_profile => time_profile,
          :derived_storage_total => 500_000_000_000,
          :derived_storage_free => 500_000_000_000 - (300_000_000_000 - i * 10_000_000_000)
        )
      end

      described_class.generate_future_events(resource)

      events = described_class.order(:id).to_a
      expect(events).to match_array([
        have_attributes(
          :timestamp  => be_within(0.01).of(20.days.from_now.beginning_of_day),
          :resource   => resource,
          :event_type => "DiskUsage",
          :severity   => 1,
          :future     => true,
          :message    => "Disk Space Max Used is projected to reach 465.7 GB (100% of Capacity - Total Space (B))"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(15.days.from_now.beginning_of_day),
          :resource   => resource,
          :event_type => "DiskUsage",
          :severity   => 1,
          :future     => true,
          :message    => "Disk Space Max Used is projected to reach 419.1 GB (90% of Capacity - Total Space (B))"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(7.days.from_now.middle_of_day),
          :resource   => resource,
          :event_type => "DiskUsage",
          :severity   => 2,
          :future     => true,
          :message    => "Disk Space Max Used is projected to reach 349.2 GB (75% of Capacity - Total Space (B))"
        ),
        have_attributes(
          :timestamp  => be_within(0.01).of(5.days.ago.beginning_of_day),
          :resource   => resource,
          :event_type => "DiskUsage",
          :severity   => 3,
          :future     => true,
          :message    => "Disk Space Max Used is projected to reach 232.8 GB (50% of Capacity - Total Space (B))"
        )
      ])
    end
  end
end
