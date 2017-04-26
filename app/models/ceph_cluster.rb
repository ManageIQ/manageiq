class CephCluster < ApplicationRecord
  has_many :usm_hosts
  has_many :ceph_osds
  has_many :ceph_pools
end
