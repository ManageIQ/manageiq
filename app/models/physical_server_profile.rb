class PhysicalServerProfile < ApplicationRecord
  acts_as_miq_taggable

  include NewWithTypeStiMixin
  include MiqPolicyMixin
  include TenantIdentityMixin
  include SupportsFeatureMixin
  include EventMixin
  include ProviderObjectMixin
  include ComplianceMixin
  include EmsRefreshMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_server_profiles,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  belongs_to :assigned_server, :foreign_key => :assigned_server_id, :optional => true, :class_name => "ManageIQ::Providers::PhysicalInfraManager::PhysicalServer"
  belongs_to :associated_server, :foreign_key => :associated_server_id, :optional => true, :class_name => "ManageIQ::Providers::PhysicalInfraManager::PhysicalServer"

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def event_where_clause(assoc = :ems_events)
    ["#{events_table_name(assoc)}.physical_server_profile_id = ?", id]
  end
end
