require_migration

describe FixEventClassForEvmAlertEvent do
  let(:event_stream_stub) { migration_stub(:EventStream) }

  migration_context :up do
    it "converts EmsCluster alert events from EmsEvent to MiqEvent" do
      cluster_id = 123
      event = event_stream_stub.create!(
        :type             => 'EmsEvent',
        :event_type       => 'EVMAlertEvent',
        :ems_cluster_id   => cluster_id,
        :ems_cluster_name => 'test_cluster',
        :ems_cluster_uid  => 'domain-c12'
      )

      migrate
      event.reload

      expect(event).to have_attributes(
        :type             => 'MiqEvent',
        :target_type      => 'EmsCluster',
        :target_id        => cluster_id,
        :ems_cluster_id   => cluster_id,
        :ems_cluster_name => 'test_cluster',
        :ems_cluster_uid  => 'domain-c12'
      )
    end

    it "converts Host alert events from EmsEvent to MiqEvent" do
      host_id = 233
      event = event_stream_stub.create!(
        :type       => 'EmsEvent',
        :event_type => 'EVMAlertEvent',
        :host_id    => host_id,
        :host_name  => 'test_host'
      )

      migrate
      event.reload

      expect(event).to have_attributes(
        :type        => 'MiqEvent',
        :target_type => 'Host',
        :target_id   => host_id,
        :host_id     => host_id,
        :host_name   => 'test_host'
      )
    end

    it "converts VmOrTemplate alert events from EmsEvent to MiqEvent" do
      vm_id = 335
      event = event_stream_stub.create!(
        :type              => 'EmsEvent',
        :event_type        => 'EVMAlertEvent',
        :vm_or_template_id => vm_id,
        :vm_name           => 'test_vm',
        :vm_location       => 'test_vm/test_vm.vmx'
      )

      migrate
      event.reload

      expect(event).to have_attributes(
        :type              => 'MiqEvent',
        :target_type       => 'VmOrTemplate',
        :target_id         => vm_id,
        :vm_or_template_id => vm_id,
        :vm_name           => 'test_vm',
        :vm_location       => 'test_vm/test_vm.vmx'
      )
    end
  end

  migration_context :down do
    let(:cluster_stub) { migration_stub(:EmsCluster) }
    let(:host_stub)    { migration_stub(:Host) }
    let(:vm_stub)      { migration_stub(:Vm) }

    it "converts EmsCluster alert events from MiqEvent to EmsEvent" do
      cluster = cluster_stub.create!(:name => 'test_cluster', :uid_ems => 'domain-c12')
      event = event_stream_stub.create!(
        :type             => 'MiqEvent',
        :event_type       => 'EVMAlertEvent',
        :target_type      => 'EmsCluster',
        :target_id        => cluster.id,
        :ems_cluster_id   => cluster.id,
        :ems_cluster_name => cluster.name,
        :ems_cluster_uid  => cluster.uid_ems
      )

      migrate
      event.reload

      expect(event).to have_attributes(
        :type             => 'EmsEvent',
        :target_type      => nil,
        :target_id        => nil,
        :ems_cluster_id   => cluster.id,
        :ems_cluster_name => cluster.name,
        :ems_cluster_uid  => cluster.uid_ems
      )
    end

    it "converts Host alert events from MiqEvent to EmsEvent" do
      host = host_stub.create!(:name => 'test_host')
      event = event_stream_stub.create!(
        :type        => 'MiqEvent',
        :event_type  => 'EVMAlertEvent',
        :target_type => 'Host',
        :target_id   => host.id,
        :host_id     => host.id,
        :host_name   => host.name
      )

      migrate
      event.reload

      expect(event).to have_attributes(
        :type        => 'EmsEvent',
        :target_type => nil,
        :target_id   => nil,
        :host_id     => host.id,
        :host_name   => host.name
      )
    end

    it "converts VmOrTemplate alert events from MiqEvent to EmsEvent" do
      vm = vm_stub.create!(:name => 'test_vm', :location => 'test_vm/test_vm.vmx')
      event = event_stream_stub.create!(
        :type              => 'MiqEvent',
        :event_type        => 'EVMAlertEvent',
        :target_type       => 'VmOrTemplate',
        :target_id         => vm.id,
        :vm_or_template_id => vm.id,
        :vm_name           => vm.name,
        :vm_location       => vm.location
      )

      migrate
      event.reload

      expect(event).to have_attributes(
        :type              => 'EmsEvent',
        :target_type       => nil,
        :target_id         => nil,
        :vm_or_template_id => vm.id,
        :vm_name           => vm.name,
        :vm_location       => vm.location
      )
    end
  end
end
