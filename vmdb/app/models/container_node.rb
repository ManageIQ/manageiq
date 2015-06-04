class ContainerNode < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  # :name, :uid, :creation_timestamp, :resource_version
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many   :container_groups
  has_many   :container_node_conditions, :dependent => :destroy
  has_one    :computer_system, :as => :managed_entity, :dependent => :destroy
  belongs_to :lives_on, :polymorphic => true

  delegate   :hardware, :to => :computer_system

  virtual_column :ready_condition_status, :type => :string, :uses => :container_node_conditions

  def ready_condition
    container_node_conditions.find_by_name('Ready')
  end

  def ready_condition_status
    ready_condition.try(:status) || 'None'
  end
end
