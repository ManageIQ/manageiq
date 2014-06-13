require "spec_helper"
require Rails.root.join("db/migrate/20120827162810_add_ems_cluster_id_to_hosts_and_vms.rb")

describe AddEmsClusterIdToHostsAndVms do
  migration_context :up do
    let(:relationship_stub)       { migration_stub(:Relationship) }
    let(:host_stub)               { migration_stub(:Host) }

    it "adds ems_cluster_id to hosts" do
      cluster_rel = relationship_stub.create!(
        :resource_type => 'EmsCluster',
        :resource_id => 123
      )
      host = host_stub.create!
      host_id = host.id
      host_rel = relationship_stub.create!(
        :resource_type => 'Host',
        :resource_id => host_id,
        :ancestry => "#{cluster_rel.id}"
      )

      migrate

     host_stub.find(host_id).ems_cluster_id.should == 123
     lambda {host_rel.reload}.should raise_error ActiveRecord::RecordNotFound
    end
  end
end
