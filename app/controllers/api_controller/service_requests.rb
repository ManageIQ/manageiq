class ApiController
  module ServiceRequests
    #
    # Service Requests Subcollection Supporting Methods
    #
    def service_requests_query_resource(object)
      return {} unless object
      klass = collection_class(:service_requests)

      case object
      when collection_class(:service_orders)
        klass.where(:service_order_id => object.id)
      else
        klass.where(:source_id => object.id)
      end
    end
  end
end
