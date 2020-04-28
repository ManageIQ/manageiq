class StorageProfile < ApplicationRecord
  belongs_to :ext_management_system,  :foreign_key => :ems_id
  has_many :storage_profile_storages, :dependent  => :destroy
  has_many :storages,                 :through    => :storage_profile_storages
  has_many :vms_and_templates,        :dependent  => :nullify
  has_many :disks,                    :dependent  => :nullify

  acts_as_miq_taggable
end
