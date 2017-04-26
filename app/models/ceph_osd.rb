class CephOsd < ApplicationRecord
  has_and_belongs_to_many :ceph_pools
  has_one :disk, :as => :backing
end
