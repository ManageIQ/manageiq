class ShareMember < ApplicationRecord
  belongs_to :share
  belongs_to :shareable, :polymorphic => true
end
