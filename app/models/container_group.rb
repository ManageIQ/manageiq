class ContainerGroup < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin
  include NewWithTypeStiMixin

  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :restart_policy, :dns_policy

  has_many :containers,
           :through => :container_definitions
  has_many :container_definitions, :dependent => :destroy
  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :labels, -> { where(:section => "labels") }, :class_name => CustomAttribute, :as => :resource, :dependent => :destroy
  has_many :node_selector_parts, -> { where(:section => "node_selectors") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :container_conditions, :class_name => ContainerCondition, :as => :container_entity, :dependent => :destroy
  belongs_to :container_node
  has_and_belongs_to_many :container_services, :join_table => :container_groups_container_services
  belongs_to :container_replicator
  belongs_to :container_project

  virtual_column :ready_condition_status, :type => :string, :uses => :container_conditions

  def ready_condition
    container_conditions.find_by(:name => "Ready")
  end

  def ready_condition_status
    ready_condition.try(:status) || 'None'
  end

  # validates :restart_policy, :inclusion => { :in => %w(always onFailure never) }
  # validates :dns_policy, :inclusion => { :in => %w(ClusterFirst Default) }

  include EventMixin

  acts_as_miq_taggable

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events
      # TODO: improve relationship using the id
      ["container_namespace = ? AND container_group_name = ? AND #{events_table_name(assoc)}.ems_id = ?",
       container_project.name, name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["#{events_table_name(assoc)}.ems_id = ?", ems_id]
    end
  end
end
