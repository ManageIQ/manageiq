class PolicyEventContent < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  belongs_to :policy_event
end
