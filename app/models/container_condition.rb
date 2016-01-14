class ContainerCondition < ApplicationRecord
  include ReportableMixin
  belongs_to :container_entity, :polymorphic => true
end
