class MiqSetMembership < ApplicationRecord
  belongs_to :miq_set
  belongs_to :member, :polymorphic => true
end
