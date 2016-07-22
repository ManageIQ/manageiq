class ApiController
  INVALID_QUEUE_ATTRS = %w(id href state lock_version)

  module Queue
    def create_resource_queue(_type, _id, data)
      validate_queue_data(data)

      zone = fetch_zone(data)
      data[:zone] = zone.name if zone

      MiqQueue.put(data)
    end

    private

    def validate_queue_data(data)
      invalid_attrs = data.keys & INVALID_QUEUE_ATTRS
      raise BadRequestError, "Invalid attributes(s) #{invalide_attrs}" unless invalid_attrs.empty?
    end
  end
end