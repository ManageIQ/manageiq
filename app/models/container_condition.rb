class ContainerCondition < ApplicationRecord
  belongs_to :container_entity, :polymorphic => true
end
