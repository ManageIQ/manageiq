module ArRegion
  extend ActiveSupport::Concern

  included do
    cache_with_timeout(:id_to_miq_region) { Hash.new }
  end

  module ClassMethods
    def inherited(other)
      if other == other.base_class
        other.class_eval do
          virtual_column :region_number,      :type => :integer # This method is defined in ActiveRecord::IdRegions
          virtual_column :region_description, :type => :string
        end
      end
      super
    end
  end

  def miq_region
    self.class.id_to_miq_region[region_number] || (self.class.id_to_miq_region[region_number] = MiqRegion.where(:region => region_number).first)
  end

  def region_description
    miq_region.description if miq_region
  end
end
