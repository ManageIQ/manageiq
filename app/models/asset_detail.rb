class AssetDetail < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
end
