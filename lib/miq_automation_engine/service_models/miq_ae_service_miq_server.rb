module MiqAeMethodService
  class MiqAeServiceMiqServer < MiqAeServiceModelBase
    expose :zone, :method => :my_zone

    def region_number
      MiqRegion.my_region.try(:region)
    end

    def region_name
      MiqRegion.my_region.try(:name)
    end
  end
end
