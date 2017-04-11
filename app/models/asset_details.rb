class AssetDetails < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :physical_server, :inverse_of => :asset_details

end
