class PhysicalServerProfileTemplate < ApplicationRecord
  acts_as_miq_taggable

  include NewWithTypeStiMixin
  include TenantIdentityMixin
  include SupportsFeatureMixin
  include EventMixin
  include ProviderObjectMixin
  include EmsRefreshMixin

  include_concern 'Operations'

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_server_profile_templates,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"


  delegate :queue_name_for_ems_operations, :to => :ext_management_system, :allow_nil => true

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end
end
