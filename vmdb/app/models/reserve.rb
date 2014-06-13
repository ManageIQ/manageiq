class Reserve < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true

  serialize :reserved
end
