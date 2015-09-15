class ContainerCondition < ActiveRecord::Base
  include ReportableMixin
  belongs_to :container_entity, :polymorphic => true
end
