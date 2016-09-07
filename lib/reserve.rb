class Reserve < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  serialize :reserved
end
