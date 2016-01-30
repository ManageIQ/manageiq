describe BottleneckEvent do
  describe ".future_event_definitions_for_obj" do
    it "contains things" do
      MiqEventDefinition.seed_default_definitions
      expect(BottleneckEvent.future_event_definitions_for_obj(ManageIQ::Providers::Vmware::InfraManager::Host.new)).not_to be_empty
    end
  end

  describe ".event_where_clause" do
    it "queries enterprises" do
      ent = FactoryGirl.create(:miq_enterprise)
      query = described_class.event_where_clause(ent)
      expect(query).to match(/resource_type = 'MiqEnterprise'/)
    end

    it "queries enterprises with ems" do
      ent = FactoryGirl.create(:miq_enterprise)
      FactoryGirl.create(:ext_management_system)
      query = described_class.event_where_clause(ent)
      expect(query).to match(/resource_type = 'MiqEnterprise'.*resource_type = 'ExtManagementSystem'/)
    end

    it "queries enterprises with storage" do
      ent = FactoryGirl.create(:miq_enterprise)
      FactoryGirl.create(:storage)
      query = described_class.event_where_clause(ent)
      expect(query).to match(/resource_type = 'MiqEnterprise'.*resource_type = 'Storage'/)
    end

    it "queries regions" do
      reg = FactoryGirl.create(:miq_region)
      query = described_class.event_where_clause(reg)
      expect(query).to match(/resource_type = 'MiqRegion'/)
    end

    it "queries regions with ems" do
      reg = FactoryGirl.create(:miq_region)
      FactoryGirl.create(:ext_management_system)
      query = described_class.event_where_clause(reg)
      expect(query).to match(/resource_type = 'MiqRegion'.*resource_type = 'ExtManagementSystem'/)
    end

    it "queries regions with storage" do
      reg = FactoryGirl.create(:miq_region)
      FactoryGirl.create(:storage)
      query = described_class.event_where_clause(reg)
      expect(query).to match(/resource_type = 'MiqRegion'.*resource_type = 'Storage'/)
    end

    it "queries ems" do
      ems = FactoryGirl.create(:ext_management_system)
      query = described_class.event_where_clause(ems)
      expect(query).to match(/resource_type = 'ExtManagementSystem'/)
    end

    it "queries ems with cluster" do
      ems = FactoryGirl.create(:ext_management_system)
      FactoryGirl.create(:ems_cluster, :ext_management_system => ems)
      query = described_class.event_where_clause(ems)
      expect(query).to match(/resource_type = 'ExtManagementSystem'.*resource_type = 'EmsCluster'/)
    end

    it "queries ems with host" do
      ems = FactoryGirl.create(:ext_management_system)
      FactoryGirl.create(:host, :ext_management_system => ems)
      query = described_class.event_where_clause(ems)
      expect(query).to match(/resource_type = 'ExtManagementSystem'.*resource_type = 'Host'/)
    end

    it "queries cluster with host" do
      cluster = FactoryGirl.create(:ems_cluster)
      FactoryGirl.create(:host, :ems_cluster => cluster)
      query = described_class.event_where_clause(cluster)
      expect(query).to match(/resource_type = 'EmsCluster'.*resource_type = 'Host'/)
    end
  end

  describe ".last_created_on" do
    subject { described_class.last_created_on(resource) }
    let(:resource) { FactoryGirl.create(resource_name) }
    let!(:bottleneck_event) { BottleneckEvent.create!(:resource => resource) }

    context "for a host_redhat resource" do
      let(:resource_name) { :host_redhat }
      it { is_expected.to be_same_time_as(bottleneck_event.created_on) }
    end

    context "for a host_vmware resource" do
      let(:resource_name) { :host_vmware }
      it { is_expected.to be_same_time_as(bottleneck_event.created_on) }
    end

    context "for a miq_enterprise resource" do
      let(:resource_name) { :miq_enterprise }
      it { is_expected.to be_same_time_as(bottleneck_event.created_on) }
    end

    context "for a ems_redhat resource" do
      let(:resource_name) { :ems_redhat }
      it { is_expected.to be_same_time_as(bottleneck_event.created_on) }
    end

    context "for a ems_cluster_openstack resource" do
      let(:resource_name) { :ems_cluster_openstack }
      it { is_expected.to be_same_time_as(bottleneck_event.created_on) }
    end
  end

  describe ".delete_future_events_for_obj" do
    let(:resource) { FactoryGirl.create(resource_name) }
    let!(:bottleneck_event) { BottleneckEvent.create!(:resource => resource, :future => true) }

    before { BottleneckEvent.delete_future_events_for_obj(resource) }

    context "for a host_redhat resource" do
      let(:resource_name) { :host_redhat }
      it "deletes the future event" do
        expect { bottleneck_event.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end

    context "for a host_vmware resource" do
      let(:resource_name) { :host_vmware }
      it "deletes the future event" do
        expect { bottleneck_event.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end

    context "for a miq_enterprise resource" do
      let(:resource_name) { :miq_enterprise }
      it "deletes the future event" do
        expect { bottleneck_event.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end

    context "for a ems_cluster_openstack resource" do
      let(:resource_name) { :ems_cluster_openstack }
      it "deletes the future event" do
        expect { bottleneck_event.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
  end
end
