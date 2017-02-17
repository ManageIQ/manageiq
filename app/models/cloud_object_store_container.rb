class CloudObjectStoreContainer < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :cloud_tenant
  has_many   :cloud_object_store_objects

  acts_as_miq_taggable

  include ProviderObjectMixin
  include NewWithTypeStiMixin
  include ProcessTasksMixin
  include SupportsFeatureMixin

  include_concern 'Operations'

  alias_attribute :name, :key

  supports_not :delete, :reason => N_("Delete operation is not supported.")
end
