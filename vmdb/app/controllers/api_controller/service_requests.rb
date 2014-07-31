class ApiController
  module ServiceRequests
    #
    # Service Requests Subcollection Supporting Methods
    #
    def service_requests_query_resource(object)
      klass = collection_config[:service_requests][:klass].constantize
      object ? klass.where(:source_id => object.id) : {}
    end
  end
end
