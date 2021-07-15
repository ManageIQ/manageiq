class MiqSetMembership < ApplicationRecord
  # NOTE:  Can't set `belongs_to :miq_set` here because `MiqSet` is not a model
  belongs_to :member, :polymorphic => true
end
