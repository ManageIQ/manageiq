class AssetDetail < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :physical_server, :polymorphic => true
end
