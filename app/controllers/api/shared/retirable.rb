module Api
  module Shared
    module Retirable
      def retire_resource(type, id, data = nil)
        klass = collection_class(type)
        if id
          msg = "Retiring #{type} id #{id}"
          resource = resource_search(id, type, klass)
          if data && data["date"]
            opts = {}
            opts[:date] = data["date"]
            opts[:warn] = data["warn"] if data["warn"]
            msg << " on: #{opts}"
            api_log_info(msg)
            resource.retire(opts)
          else
            msg << " immediately."
            api_log_info(msg)
            resource.retire_now
          end
          resource
        else
          raise BadRequestError, "Must specify an id for retiring a #{type} resource"
        end
      end
      alias generic_retire_resource retire_resource
    end
  end
end
