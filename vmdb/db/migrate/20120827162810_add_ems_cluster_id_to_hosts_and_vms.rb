class AddEmsClusterIdToHostsAndVms < ActiveRecord::Migration
  class Host < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  class Relationship < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    change_table(:vms)   { |t| t.belongs_to :ems_cluster, :type => :bigint }
    change_table(:hosts) { |t| t.belongs_to :ems_cluster, :type => :bigint }

    say_with_time("Migrate Host-Cluster relationships to new column") do
      cluster_rels    = Relationship.where(:resource_type => "EmsCluster").index_by(&:id)
      cluster_rel_ids = cluster_rels.keys

      host_rels       = Relationship.where(:resource_type => "Host")
      hosts           = Host.where(:id => host_rels.collect(&:resource_id)).index_by(&:id)

      host_rels.each do |r|
        ancestry_ids   = r.ancestry.split("/").collect(&:to_i)
        cluster_rel_id = (ancestry_ids & cluster_rel_ids).first

        if cluster_rel_id
          unless hosts[r.resource_id].nil?
            hosts[r.resource_id].update_attribute(:ems_cluster_id, cluster_rels[cluster_rel_id].resource_id)
          end
          r.destroy
        end
      end
    end
  end

  def down
    change_table(:vms)   { |t| t.remove_belongs_to :ems_cluster }
    change_table(:hosts) { |t| t.remove_belongs_to :ems_cluster }
  end
end
