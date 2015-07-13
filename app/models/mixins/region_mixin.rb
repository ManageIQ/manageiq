module RegionMixin
  extend ActiveSupport::Concern

  included do
    before_validation :set_region
  end

  def set_region
    self.region ||= MiqRegion.my_region_number
  end
end
