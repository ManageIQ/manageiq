class ApiController
  module ServiceRequests
    #
    # Service Requests Subcollection Supporting Methods
    #
    def service_requests_query_resource(object)
      klass = collection_class(:service_requests)
      object ? klass.where(:source_id => object.id) : {}
    end
  end
end
