RSpec.describe ServiceTemplateTransformationPlan, :v2v do
  before { EvmSpecHelper.local_miq_server } # required for creating snapshots needed for warm migration testing
  subject { FactoryBot.create(:service_template_transformation_plan) }

  describe '#request_class' do
    it { expect(subject.request_class).to eq(ServiceTemplateTransformationPlanRequest) }
  end

  describe '#request_type' do
    it { expect(subject.request_type).to eq("transformation_plan") }
  end

  let(:apst) { FactoryBot.create(:service_template_ansible_playbook) }
  let(:vm1) { FactoryBot.create(:vm_vmware) }
  let(:vm2) { FactoryBot.create(:vm_vmware) }
  let(:vm3) { FactoryBot.create(:vm_vmware) }
  let(:security_group1) { FactoryBot.create(:security_group, :name => "default") }
  let(:flavor1) { FactoryBot.create(:flavor, :name => "large") }
  let(:security_group2) { FactoryBot.create(:security_group, :name => "default") }
  let(:flavor2) { FactoryBot.create(:flavor, :name => "medium") }
  let(:sg_md) { FactoryBot.create(:security_group, :name => "manageiq-dev") }
  let(:sg_ch) { FactoryBot.create(:security_group, :name => "converison-host") }
  let(:sg_cf) { FactoryBot.create(:security_group, :name => "migration") }

  let(:src_ems_vmware) { FactoryBot.create(:ems_vmware) }
  let(:dst_ems_redhat) { FactoryBot.create(:ems_redhat) }
  let(:src_cluster_vmware) { FactoryBot.create(:ems_cluster, :ext_management_system => src_ems_vmware) }
  let(:dst_ems_openstack) { FactoryBot.create(:ems_openstack) }
  let(:dst_cluster_redhat) { FactoryBot.create(:ems_cluster, :ext_management_system => dst_ems_redhat) }

  let(:src_hosts_vmware) { FactoryBot.create_list(:host_vmware, 1, :ems_cluster => src_cluster_vmware) }
  let(:dst_hosts_redhat) { FactoryBot.create_list(:host_redhat, 1, :ems_cluster => dst_cluster_redhat) }

  let(:src_storages_vmware) { FactoryBot.create_list(:storage, 1, :hosts => src_hosts_vmware) }
  let(:dst_storages_redhat) { FactoryBot.create_list(:storage, 1, :hosts => dst_hosts_redhat) }

  let(:src_switches_vmware) { FactoryBot.create_list(:switch, 1, :hosts => src_hosts_vmware) }
  let(:dst_switches_redhat) { FactoryBot.create_list(:switch, 1, :hosts => dst_hosts_redhat) }

  let(:src_lans_vmware) { FactoryBot.create_list(:lan, 1, :switch => src_switches_vmware.first) }
  let(:dst_lans_redhat) { FactoryBot.create_list(:lan, 1, :switch => dst_switches_redhat.first) }

  let(:dst_cloud_tenant_openstack) do
    FactoryBot.create(:cloud_tenant,
                      :ext_management_system => dst_ems_openstack,
                      :flavors               => [flavor1, flavor2],
                      :security_groups       => [security_group1, security_group2, sg_md, sg_ch, sg_cf])
  end
  let(:mapping_openstack) do
    FactoryBot.create(:transformation_mapping).tap do |tm|
      tm.transformation_mapping_items = [
        FactoryBot.create(:transformation_mapping_item,
                          :source                 => src_cluster_vmware,
                          :destination            => dst_cloud_tenant_openstack,
                          :transformation_mapping => tm)
      ]
    end
  end

  let(:transformation_mapping) do
    FactoryBot.create(:transformation_mapping).tap do |tm|
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => src_cluster_vmware,
                        :destination            => dst_cluster_redhat,
                        :transformation_mapping => tm)
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => src_storages_vmware.first,
                        :destination            => dst_storages_redhat.first,
                        :transformation_mapping => tm)
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => src_lans_vmware.first,
                        :destination            => dst_lans_redhat.first,
                        :transformation_mapping => tm)
    end
  end
  let(:transformation_mapping2) do
    FactoryBot.create(:transformation_mapping).tap do |tm|
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => src_cluster_vmware,
                        :destination            => dst_cluster_redhat,
                        :transformation_mapping => tm)
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => src_storages_vmware.first,
                        :destination            => dst_storages_redhat.first,
                        :transformation_mapping => tm)
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => src_lans_vmware.first,
                        :destination            => dst_lans_redhat.first,
                        :transformation_mapping => tm)
    end
  end

  let(:atst) { FactoryBot.create(:service_template_ansible_tower) }
  let(:security_group_bad) { FactoryBot.create(:security_group, :name => "sg_bad") }
  let(:flavor_bad) { FactoryBot.create(:flavor, :name => "flavor_bad") }

  let(:catalog_item_options) do
    {
      :name        => 'Transformation Plan',
      :description => 'a description',
      :config_info => {
        :transformation_mapping_id => transformation_mapping.id,
        :pre_service_id            => apst.id,
        :post_service_id           => apst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor1.id},
          {:vm_id => vm2.id.to_s, :pre_service => true, :post_service => true, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor1.id}
        ],
      }
    }
  end

  let(:catalog_item_options_bad_premigration) do
    {
      :name        => 'Transformation Plan',
      :description => 'a description',
      :config_info => {
        :transformation_mapping_id => mapping_openstack.id,
        :pre_service_id            => atst.id,
        :post_service_id           => apst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor1.id},
          {:vm_id => vm2.id.to_s, :pre_service => true, :post_service => true, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor1.id}
        ],
      }
    }
  end

  let(:catalog_item_options_bad_postmigration) do
    {
      :name        => 'Transformation Plan',
      :description => 'a description',
      :config_info => {
        :transformation_mapping_id => mapping_openstack.id,
        :pre_service_id            => apst.id,
        :post_service_id           => atst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor1.id},
          {:vm_id => vm2.id.to_s, :pre_service => true, :post_service => true, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor1.id}
        ],
      }
    }
  end

  let(:catalog_item_options_bad_security_group) do
    {
      :name        => 'Transformation Plan',
      :description => 'a description',
      :config_info => {
        :transformation_mapping_id => mapping_openstack.id,
        :pre_service_id            => apst.id,
        :post_service_id           => apst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false, :osp_security_group_id => security_group_bad.id, :osp_flavor_id => flavor1.id},
          {:vm_id => vm2.id.to_s, :pre_service => true, :post_service => true, :osp_security_group_id => security_group_bad.id, :osp_flavor_id => flavor1.id}
        ],
      }
    }
  end

  let(:catalog_item_options_bad_flavor) do
    {
      :name        => 'Transformation Plan',
      :description => 'a description',
      :config_info => {
        :transformation_mapping_id => mapping_openstack.id,
        :pre_service_id            => apst.id,
        :post_service_id           => apst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor_bad.id},
          {:vm_id => vm2.id.to_s, :pre_service => true, :post_service => true, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor_bad.id}
        ],
      }
    }
  end

  let(:updated_catalog_item_options_with_vms_added) do
    {
      :name        => 'Transformation Plan Updated',
      :description => 'an updated description',
      :config_info => {
        :transformation_mapping_id => transformation_mapping.id,
        :pre_service_id            => apst.id,
        :post_service_id           => apst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor1.id},
          {:vm_id => vm2.id.to_s, :pre_service => true, :post_service => true, :osp_security_group_id => security_group1.id, :osp_flavor_id => flavor1.id},
          {:vm_id => vm3.id.to_s, :pre_service => true, :post_service => true, :osp_security_group_id => security_group2.id, :osp_flavor_id => flavor2.id}
        ],
      }
    }
  end

  let(:updated_catalog_item_options_with_vms_removed) do
    {
      :name        => 'Transformation Plan Updated',
      :description => 'an updated description',
      :config_info => {
        :transformation_mapping_id => transformation_mapping.id,
        :pre_service_id            => apst.id,
        :post_service_id           => apst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false}
        ],
      }
    }
  end

  let(:updated_catalog_item_options_with_vms_added_and_removed) do
    {
      :name        => 'Transformation Plan Updated',
      :description => 'an updated description',
      :config_info => {
        :transformation_mapping_id => transformation_mapping.id,
        :pre_service_id            => apst.id,
        :post_service_id           => apst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false},
          {:vm_id => vm3.id.to_s, :pre_service => true, :post_service => true}
        ],
      }
    }
  end

  let(:updated_catalog_item_options_with_updated_transformation_mapping) do
    {
      :name        => 'Transformation Plan Updated',
      :description => 'an updated description',
      :config_info => {
        :transformation_mapping_id => transformation_mapping2.id,
        :pre_service_id            => apst.id,
        :post_service_id           => apst.id,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false},
          {:vm_id => vm2.id.to_s, :pre_service => true, :post_service => true}
        ],
      }
    }
  end

  let(:updated_catalog_item_options_with_warm_migration) do
    {
      :name        => 'Transformation Plan Updated',
      :description => 'an updated description',
      :config_info => {
        :transformation_mapping_id => transformation_mapping2.id,
        :pre_service_id            => apst.id,
        :post_service_id           => apst.id,
        :warm_migration            => true,
        :actions                   => [
          {:vm_id => vm1.id.to_s, :pre_service => true, :post_service => false},
          {:vm_id => vm2.id.to_s, :pre_service => true, :post_service => true}
        ],
      }
    }
  end

  let(:miq_requests) { [FactoryBot.create(:service_template_transformation_plan_request, :request_state => "finished")] }
  let(:miq_requests_with_in_progress_request) { [FactoryBot.create(:service_template_transformation_plan_request, :request_state => "active")] }

  it "doesn’t access database when unchanged model is saved" do
    f1 = described_class.create!(:name => 'f1')
    expect { f1.valid? }.not_to make_database_queries
  end

  describe '#validate_order' do
    let(:service_template) { described_class.create_catalog_item(catalog_item_options) }

    it 'allows a plan to be ordered if all VMs have not been migrated' do
      expect(service_template.validate_order).to eql(true)
      expect(service_template.orderable?).to eql(true) # alias
    end

    it 'denies a plan from bring ordered if all VMs have been migrated' do
      vm1.tag_add('transformation_status/migrated', :ns => '/managed')
      vm2.tag_add('transformation_status/migrated', :ns => '/managed')
      expect(service_template.validate_order).to eql(false)
      expect(service_template.orderable?).to eql(false) # alias
      expect(service_template.unsupported_reason(:order)).to eq('All VMs of the migration plan have already been successfully migrated')
    end
  end

  describe '.public_service_templates' do
    it 'display public service templates' do
      st1 = FactoryBot.create(:service_template_transformation_plan)
      st2 = FactoryBot.create(:service_template)

      expect(st1.internal?).to be_truthy
      expect(st2.internal?).to be_falsey
      expect(ServiceTemplate.public_service_templates).to match_array([st2])
    end
  end

  describe '.create_catalog_item' do
    it 'creates and returns a transformation plan' do
      service_template = described_class.create_catalog_item(catalog_item_options)

      expect(service_template.name).to eq('Transformation Plan')
      expect(service_template.transformation_mapping).to eq(transformation_mapping)
      expect(service_template.vm_resources.collect(&:resource)).to match_array([vm1, vm2])
      expect(service_template.vm_resources.collect(&:status)).to eq([ServiceResource::STATUS_QUEUED, ServiceResource::STATUS_QUEUED])
      expect(service_template.vm_resources.find_by(:resource_id => vm1.id).options).to eq(
        "pre_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                    => security_group1.id,
        "osp_flavor_id"                            => flavor1.id,
        "warm_migration_compatible"                => true,
        "warm_migration"                           => false
      )
      expect(service_template.vm_resources.find_by(:resource_id => vm2.id).options).to eq(
        "pre_ansible_playbook_service_template_id"  => apst.id,
        "post_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                     => security_group1.id,
        "osp_flavor_id"                             => flavor1.id,
        "warm_migration_compatible"                 => true,
        "warm_migration"                            => false
      )
      expect(service_template.config_info).to eq(catalog_item_options[:config_info])
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point(nil)
      )
    end

    it 'creates and returns a transformation plan with VMs containing snapshots' do
      FactoryBot.create_list(:snapshot, 2, :create_time => 1.minute.ago, :vm_or_template => vm1)
      FactoryBot.create_list(:snapshot, 2, :create_time => 1.minute.ago, :vm_or_template => vm2)

      service_template = described_class.create_catalog_item(catalog_item_options)

      expect(service_template.vm_resources.find_by(:resource_id => vm1.id).options).to eq(
        "pre_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                    => security_group1.id,
        "osp_flavor_id"                            => flavor1.id,
        "warm_migration_compatible"                => false,
        "warm_migration"                           => false
      )
      expect(service_template.vm_resources.find_by(:resource_id => vm2.id).options).to eq(
        "pre_ansible_playbook_service_template_id"  => apst.id,
        "post_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                     => security_group1.id,
        "osp_flavor_id"                             => flavor1.id,
        "warm_migration_compatible"                 => false,
        "warm_migration"                            => false
      )
    end

    it 'requires a transformation mapping' do
      catalog_item_options[:config_info].delete(:transformation_mapping_id)

      expect do
        described_class.create_catalog_item(catalog_item_options)
      end.to raise_error(StandardError, 'Must provide an existing transformation mapping')
    end

    it 'requires selected vms' do
      catalog_item_options[:config_info].delete(:actions)

      expect do
        described_class.create_catalog_item(catalog_item_options)
      end.to raise_error(StandardError, 'Must select a list of valid vms')
    end

    it 'validates unique name' do
      described_class.create_catalog_item(catalog_item_options)
      expect { described_class.create_catalog_item(catalog_item_options) }.to raise_error(
        ActiveRecord::RecordInvalid, 'Validation failed: ServiceTemplateTransformationPlan: Name has already been taken'
      )
    end

    it 'requires premigration service template ansible playbook' do
      expect do
        described_class.create_catalog_item(catalog_item_options_bad_premigration)
      end.to raise_error(StandardError, 'Premigration service type MUST be "ServiceTemplateAnsiblePlaybook"')
    end

    it 'requires postmigration service template ansible playbook' do
      # catalog_item_options_bad_prepost
      expect do
        described_class.create_catalog_item(catalog_item_options_bad_postmigration)
      end.to raise_error(StandardError, 'Postmigration service type MUST be "ServiceTemplateAnsiblePlaybook"')
    end

    it 'requires flavor associated to the cluster/cloud_tenant' do
      expect do
        described_class.create_catalog_item(catalog_item_options_bad_flavor)
      end.to raise_error(StandardError, 'VM flavor does not belong to the cloud_tenant_flavors')
    end

    it 'requires security_group associated to the cluster/cloud_tenant' do
      expect do
        described_class.create_catalog_item(catalog_item_options_bad_security_group)
      end.to raise_error(StandardError, 'VM security group does not belong to the cloud_tenant_security_groups')
    end
  end

  describe '#update_catalog_item' do
    it 'updates the associated transformation mapping' do
      service_template = described_class.create_catalog_item(catalog_item_options)
      service_template.miq_requests = []
      service_template.update_catalog_item(updated_catalog_item_options_with_updated_transformation_mapping)
      expect(service_template.name).to eq('Transformation Plan Updated')
      expect(service_template.transformation_mapping).to eq(transformation_mapping2)
    end

    it 'updates the warm migration option for all vms' do
      service_template = described_class.create_catalog_item(catalog_item_options)
      service_template.miq_requests = []
      service_template.update_catalog_item(updated_catalog_item_options_with_warm_migration)
      expect(service_template.vm_resources.find_by(:resource_id => vm1.id).options).to eq(
        "pre_ansible_playbook_service_template_id" => apst.id,
        "warm_migration_compatible"                => true,
        "warm_migration"                           => true
      )
      expect(service_template.vm_resources.find_by(:resource_id => vm2.id).options).to eq(
        "pre_ansible_playbook_service_template_id"  => apst.id,
        "post_ansible_playbook_service_template_id" => apst.id,
        "warm_migration_compatible"                 => true,
        "warm_migration"                            => true
      )
      expect(service_template.config_info).to eq(updated_catalog_item_options_with_warm_migration[:config_info])
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point(nil)
      )
    end

    it 'updates by adding new VMs to existing VMs and returns a transformation plan' do
      service_template = described_class.create_catalog_item(catalog_item_options)
      service_template.miq_requests = []
      service_template.update_catalog_item(updated_catalog_item_options_with_vms_added)

      expect(service_template.name).to eq('Transformation Plan Updated')
      expect(service_template.transformation_mapping).to eq(transformation_mapping)
      expect(service_template.vm_resources.collect(&:resource)).to match_array([vm1, vm2, vm3])
      expect(service_template.vm_resources.collect(&:status)).to eq([ServiceResource::STATUS_QUEUED, ServiceResource::STATUS_QUEUED, ServiceResource::STATUS_QUEUED])
      expect(service_template.vm_resources.find_by(:resource_id => vm1.id).options).to eq(
        "pre_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                    => security_group1.id,
        "osp_flavor_id"                            => flavor1.id,
        "warm_migration_compatible"                => true,
        "warm_migration"                           => false
      )
      expect(service_template.vm_resources.find_by(:resource_id => vm2.id).options).to eq(
        "pre_ansible_playbook_service_template_id"  => apst.id,
        "post_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                     => security_group1.id,
        "osp_flavor_id"                             => flavor1.id,
        "warm_migration_compatible"                 => true,
        "warm_migration"                            => false
      )
      expect(service_template.vm_resources.find_by(:resource_id => vm3.id).options).to eq(
        "pre_ansible_playbook_service_template_id"  => apst.id,
        "post_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                     => security_group2.id,
        "osp_flavor_id"                             => flavor2.id,
        "warm_migration_compatible"                 => true,
        "warm_migration"                            => false
      )
      expect(service_template.config_info).to eq(updated_catalog_item_options_with_vms_added[:config_info])
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point(nil)
      )
    end

    it 'updates by removing some VMs from the existing VMs and returns a transformation plan' do
      service_template = described_class.create_catalog_item(catalog_item_options)
      service_template.miq_requests = []
      service_template.update_catalog_item(updated_catalog_item_options_with_vms_removed)

      expect(service_template.name).to eq('Transformation Plan Updated')
      expect(service_template.transformation_mapping).to eq(transformation_mapping)
      expect(service_template.vm_resources.collect(&:resource)).to match_array([vm1])
      expect(service_template.vm_resources.collect(&:status)).to eq([ServiceResource::STATUS_QUEUED])
      expect(service_template.vm_resources.find_by(:resource_id => vm1.id).options).to eq(
        "pre_ansible_playbook_service_template_id" => apst.id,
        "warm_migration_compatible"                => true,
        "warm_migration"                           => false
      )
      expect(service_template.config_info).to eq(updated_catalog_item_options_with_vms_removed[:config_info])
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point(nil)
      )
    end

    it 'updates by adding new VMs to the existing VMs and removing some VMs from the existing VMs and returns a transformation plan' do
      service_template = described_class.create_catalog_item(catalog_item_options)
      service_template.miq_requests = []
      service_template.update_catalog_item(updated_catalog_item_options_with_vms_added_and_removed)

      expect(service_template.name).to eq('Transformation Plan Updated')
      expect(service_template.transformation_mapping).to eq(transformation_mapping)
      expect(service_template.vm_resources.collect(&:resource)).to match_array([vm1, vm3])
      expect(service_template.vm_resources.collect(&:status)).to eq([ServiceResource::STATUS_QUEUED, ServiceResource::STATUS_QUEUED])
      expect(service_template.vm_resources.find_by(:resource_id => vm1.id).options).to eq(
        "pre_ansible_playbook_service_template_id" => apst.id,
        "warm_migration_compatible"                => true,
        "warm_migration"                           => false
      )
      expect(service_template.vm_resources.find_by(:resource_id => vm3.id).options).to eq(
        "pre_ansible_playbook_service_template_id"  => apst.id,
        "post_ansible_playbook_service_template_id" => apst.id,
        "warm_migration_compatible"                 => true,
        "warm_migration"                            => false
      )
      expect(service_template.config_info).to eq(updated_catalog_item_options_with_vms_added_and_removed[:config_info])
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point(nil)
      )
    end

    it 'updates only the basic attributes' do
      service_template = described_class.create_catalog_item(catalog_item_options)
      service_template.miq_requests = []
      service_template.update_catalog_item(:name => "Name updated", :description => "description updated")

      expect(service_template.name).to eq('Name updated')
      expect(service_template.description).to eq('description updated')
      expect(service_template.transformation_mapping).to eq(transformation_mapping)
      expect(service_template.vm_resources.collect(&:resource)).to match_array([vm1, vm2])
      expect(service_template.vm_resources.collect(&:status)).to eq([ServiceResource::STATUS_QUEUED, ServiceResource::STATUS_QUEUED])
      expect(service_template.vm_resources.find_by(:resource_id => vm1.id).options).to eq(
        "pre_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                    => security_group1.id,
        "osp_flavor_id"                            => flavor1.id,
        "warm_migration_compatible"                => true,
        "warm_migration"                           => false
      )
      expect(service_template.vm_resources.find_by(:resource_id => vm2.id).options).to eq(
        "pre_ansible_playbook_service_template_id"  => apst.id,
        "post_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                     => security_group1.id,
        "osp_flavor_id"                             => flavor1.id,
        "warm_migration_compatible"                 => true,
        "warm_migration"                            => false
      )
      expect(service_template.config_info).to eq(catalog_item_options[:config_info])
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point(nil)
      )
    end

    it 'updates only the basic attributes when completed miq_requests are present' do
      service_template = described_class.create_catalog_item(catalog_item_options)
      service_template.miq_requests = miq_requests
      service_template.update_catalog_item(updated_catalog_item_options_with_vms_added)

      expect(service_template.name).to eq('Transformation Plan Updated')
      expect(service_template.description).to eq('an updated description')
      expect(service_template.transformation_mapping).to eq(transformation_mapping)
      expect(service_template.vm_resources.collect(&:resource)).to match_array([vm1, vm2])
      expect(service_template.vm_resources.find_by(:resource_id => vm1.id).options).to eq(
        "pre_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                    => security_group1.id,
        "osp_flavor_id"                            => flavor1.id,
        "warm_migration_compatible"                => true,
        "warm_migration"                           => false
      )
      expect(service_template.vm_resources.find_by(:resource_id => vm2.id).options).to eq(
        "pre_ansible_playbook_service_template_id"  => apst.id,
        "post_ansible_playbook_service_template_id" => apst.id,
        "osp_security_group_id"                     => security_group1.id,
        "osp_flavor_id"                             => flavor1.id,
        "warm_migration_compatible"                 => true,
        "warm_migration"                            => false
      )
      expect(service_template.config_info).to eq(catalog_item_options[:config_info])
      expect(service_template.resource_actions.first).to have_attributes(
        :action => 'Provision',
        :fqname => described_class.default_provisioning_entry_point(nil)
      )
    end

    it 'raises an exception when miq_request is in progress' do
      service_template = described_class.create_catalog_item(catalog_item_options)
      service_template.miq_requests = miq_requests_with_in_progress_request
      expect do
        service_template.update_catalog_item(updated_catalog_item_options_with_vms_added)
      end.to raise_error(StandardError, 'Editing a plan in progress is prohibited')
    end

    it 'requires a transformation mapping' do
      updated_catalog_item_options_with_vms_added[:config_info].delete(:transformation_mapping_id)

      service_template = described_class.create_catalog_item(catalog_item_options)

      expect do
        service_template.update_catalog_item(updated_catalog_item_options_with_vms_added)
      end.to raise_error(StandardError, 'Must provide an existing transformation mapping')
    end

    it 'requires selected vms' do
      updated_catalog_item_options_with_vms_added[:config_info].delete(:actions)

      service_template = described_class.create_catalog_item(catalog_item_options)

      expect do
        service_template.update_catalog_item(updated_catalog_item_options_with_vms_added)
      end.to raise_error(StandardError, 'Must select a list of valid vms')
    end

    it 'updates the cutover datetime for warm migration plan' do
      service_template = described_class.create_catalog_item(updated_catalog_item_options_with_warm_migration)
      service_template.miq_requests = []
      cutover_datetime = Time.current + 3600
      service_template.update_catalog_item(:config_info => {:warm_migration_cutover_datetime => cutover_datetime.iso8601})
      expect(service_template.config_info[:warm_migration_cutover_datetime]).to eq(cutover_datetime.iso8601)
    end

    it 'rejects the cutover datetime for warm migration set to past' do
      service_template = described_class.create_catalog_item(updated_catalog_item_options_with_warm_migration)
      service_template.miq_requests = []
      cutover_datetime = Time.current - 3600
      expect { service_template.update_catalog_item(:config_info => {:warm_migration_cutover_datetime => cutover_datetime.iso8601}) }.to raise_exception(StandardError, 'Cannot set cutover date in the past')
    end

    it 'rejects invalid datetime for warm migration' do
      service_template = described_class.create_catalog_item(updated_catalog_item_options_with_warm_migration)
      service_template.miq_requests = []
      expect { service_template.update_catalog_item(:config_info => {:warm_migration_cutover_datetime => 'nonsense'}) }.to raise_exception(StandardError, 'Error parsing datetime: invalid date: "nonsense"')
    end
  end
end
