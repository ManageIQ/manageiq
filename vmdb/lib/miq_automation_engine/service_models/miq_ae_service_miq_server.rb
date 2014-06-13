module MiqAeMethodService
  class MiqAeServiceMiqServer < MiqAeServiceModelBase
    expose :zone, :method => :my_zone

    def region_number
      region = MiqRegion.my_region
      return nil if region.nil?
      return region.region
    end

    def region_name
      region = MiqRegion.my_region
      return nil if region.nil?
      return region.name
    end
  end
end
