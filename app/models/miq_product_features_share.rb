class MiqProductFeaturesShare < ApplicationRecord
  belongs_to :miq_product_feature
  belongs_to :share

  def self.display_name(number = 1)
    n_('Product Features Share', 'Product Features Shares', number)
  end
end
