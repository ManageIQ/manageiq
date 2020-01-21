RSpec.describe CloudTenant do
  let(:user)         { FactoryBot.create(:user, :userid => 'testuser') }
  let(:ems)          { FactoryBot.create(:ems_openstack) }
  let(:vm1)          { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }
  let(:vm2)          { FactoryBot.create(:vm_openstack, :ext_management_system => nil) }
  let(:vms)          { [vm1, vm2] }
  let(:template)     { FactoryBot.create(:miq_template) }
  let(:cloud_tenant) { FactoryBot.create(:cloud_tenant, :ext_management_system => ems, :vms => vms, :miq_templates => [template]) }

  it "#all_cloud_networks" do
    ems     = FactoryBot.create(:ems_openstack)
    tenant1 = FactoryBot.create(:cloud_tenant,  :ext_management_system => ems)
    tenant2 = FactoryBot.create(:cloud_tenant,  :ext_management_system => ems)
    net1    = FactoryBot.create(:cloud_network, :ext_management_system => ems.network_manager, :shared => true)
    net2    = FactoryBot.create(:cloud_network, :ext_management_system => ems.network_manager, :cloud_tenant => tenant1)
    _net3   = FactoryBot.create(:cloud_network, :ext_management_system => ems.network_manager, :cloud_tenant => tenant2)

    expect(tenant1.all_cloud_networks).to match_array([net1, net2])
  end

  describe '#total_vms' do
    it 'counts only vms' do
      cloud_tenant.reload
      expect(cloud_tenant.vms.map(&:id)).to match_array([vm1.id])
      expect(cloud_tenant.total_vms).to eq(1)

      total_vms_from_select = CloudTenant.where(:id => cloud_tenant).select(:total_vms).first[:total_vms]
      expect(total_vms_from_select).to eq(1)
      expect(total_vms_from_select).to eq(cloud_tenant.total_vms)
      expect(cloud_tenant.vms_and_templates.count).to eq(3)
    end
  end

  context "queued methods" do
    it 'queues a create task with create_tenant_queue' do
      task_id = described_class.create_cloud_tenant_queue(user.userid, ems)
      klass = ems.class.name + '::CloudTenant'

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "creating Cloud Tenant for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => klass).first).to have_attributes(
        :class_name  => klass,
        :method_name => 'create_cloud_tenant',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => [ems.id, {}]
      )
    end

    it 'requires a userid and ems for a queued create task' do
      expect { described_class.create_cloud_tenant_queue }.to raise_error(ArgumentError)
      expect { described_class.create_cloud_tenant_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues an update task with update_cloud_tenant_queue' do
      options = {:name => 'updated_cloud_tenant_name'}
      task_id = cloud_tenant.update_cloud_tenant_queue(user.userid, options)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "updating Cloud Tenant for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'update_cloud_tenant',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => [options]
      )
    end

    it 'requires a userid for a queued update task' do
      expect { cloud_tenant.update_cloud_tenant_queue }.to raise_error(ArgumentError)
    end

    it 'queues a delete task with delete_cloud_tenant_queue' do
      task_id = cloud_tenant.delete_cloud_tenant_queue(user.userid)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "deleting Cloud Tenant for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'delete_cloud_tenant',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => []
      )
    end

    it 'requires a userid for a queued delete task' do
      expect { cloud_tenant.delete_cloud_tenant_queue }.to raise_error(ArgumentError)
    end
  end
end
