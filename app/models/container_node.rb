class ContainerNode < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  # :name, :uid, :creation_timestamp, :resource_version
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many   :container_groups
  has_many   :container_conditions, :class_name => ContainerCondition, :as => :container_entity, :dependent => :destroy
  has_many   :containers, :through => :container_groups
  has_many   :container_services, -> { distinct }, :through => :container_groups
  has_many   :container_replicators, -> { distinct }, :through => :container_groups
  has_one    :computer_system, :as => :managed_entity, :dependent => :destroy
  belongs_to :lives_on, :polymorphic => true

  has_one   :hardware, :through => :computer_system

  virtual_column :ready_condition_status, :type => :string, :uses => :container_conditions

  def ready_condition
    container_conditions.find_by(:name => "Ready")
  end

  def ready_condition_status
    ready_condition.try(:status) || 'None'
  end

  def system_distribution
    computer_system.try(:operating_system).try(:distribution)
  end

  def kernel_version
    computer_system.try(:operating_system).try(:kernel_version)
  end

  include EventMixin

  acts_as_miq_taggable

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events
      # TODO: improve relationship using the id
      ["container_node_name = ? AND #{events_table_name(assoc)}.ems_id = ?", name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["#{events_table_name(assoc)}.ems_id = ?", ems_id]
    end
  end
end
