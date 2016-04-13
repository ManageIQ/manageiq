class UsmCephSchemaMigration < ActiveRecord::Migration[5.0]
  def change
    create_table :usm_hosts do |t|
      t.string    :cluster_ipaddress
      t.boolean   :usm_enabled
      t.string    :usm_status
      t.integer   :ceph_cluster_id

      t.timestamps
    end

    create_table :ceph_clusters do |t|
      t.string    :cluster_id
      t.string    :name
      t.string    :compat_version
      t.string    :workload
      t.integer   :status
      t.boolean   :usm_enabled
      t.integer   :monitoring_interval

      t.timestamps
    end

    create_table :ceph_osds do |t|
      t.string    :osd_id
      t.string    :name
      t.integer   :type
      t.string    :status
      t.string    :in
      t.boolean   :up
      t.string    :ipaddress
      t.string    :cluster_ipaddress
      t.string    :pg_summary
      t.integer   :ceph_cluster_id

      t.timestamps
    end

    create_table :ceph_pools do |t|
      t.string    :pool_id
      t.string    :name
      t.string    :type
      t.integer   :ceph_cluster_id
      t.bigint    :size
      t.string    :status
      t.integer   :num_replicas
      t.boolean   :quota_enabled
      t.bigint    :quota_max_objects
      t.bigint    :quota_max_bytes
      t.integer   :pg_num
      t.integer   :pgp_num
      t.string    :crush_ruleset
      t.bigint    :minimum_size
      t.integer   :crash_replay_interval
      t.boolean   :full
      t.boolean   :hashpspool

      t.timestamps
    end

    create_table :ceph_osds_pools do |t|
      t.belongs_to  :ceph_osds
      t.belongs_to  :ceph_pools

      t.timestamps
    end

    create_table :ceph_rbds do |t|
      t.string      :rbd_id
      t.string      :name
      t.bigint      :size
      t.integer     :ceph_pool_id
    end
  end
end
