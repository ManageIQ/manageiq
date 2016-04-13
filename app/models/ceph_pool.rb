class CephPool < ApplicationRecord
  has_and_belongs_to_many :ceph_osds
  has_many :ceph_rbds
end
