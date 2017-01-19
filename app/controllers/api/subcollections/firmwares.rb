module Api
  module Subcollections
    module Firmwares
      def firmwares_query_resource(object)
        return {} unless object.respond_to?(:firmwares)
        object.firmwares.map(&:as_json)
      end
    end
  end
end
