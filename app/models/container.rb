class Container < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  has_one    :container_group, :through => :container_definition
  has_one    :ext_management_system, :through => :container_group
  has_one    :container_node, :through => :container_group
  has_one    :container_replicator, :through => :container_group
  has_one    :container_project, :through => :container_group
  belongs_to :container_definition
  belongs_to :container_image
  has_one    :container_image_registry, :through => :container_image
  has_one    :security_context, :through => :container_definition

  include EventMixin

  acts_as_miq_taggable

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events
      # TODO: improve relationship using the id
      ["container_namespace = ? AND #{events_table_name(assoc)}.ems_id = ?", container_project.name,
       ext_management_system.id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["#{events_table_name(assoc)}.ems_id = ?", ext_management_system.id]
    end
  end
end
