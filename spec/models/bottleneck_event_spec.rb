require "spec_helper"

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
    context "returns the last created_on date" do
      def expect_last_created_on_to_eq_resource_last_created_on(resource)
        bottleneck_event = BottleneckEvent.create!(:resource => resource)
        expect(described_class.last_created_on(resource)).to eq(bottleneck_event.reload.created_on)
      end

      specify "for a host_redhat resource" do
        resource = FactoryGirl.create(:host_redhat)
        expect_last_created_on_to_eq_resource_last_created_on(resource)
      end

      specify "for a host_vmware resource" do
        resource = FactoryGirl.create(:host_vmware)
        expect_last_created_on_to_eq_resource_last_created_on(resource)
      end
      specify "for a miq_enterprise resource" do
        resource = FactoryGirl.create(:miq_enterprise)
        expect_last_created_on_to_eq_resource_last_created_on(resource)
      end

      specify "for a ems_redhat resource" do
        resource = FactoryGirl.create(:ems_redhat)
        expect_last_created_on_to_eq_resource_last_created_on(resource)
      end

      specify "for a ems_cluster_openstack resource" do
        resource = FactoryGirl.create(:ems_cluster_openstack)
        expect_last_created_on_to_eq_resource_last_created_on(resource)
      end
    end
  end
end
