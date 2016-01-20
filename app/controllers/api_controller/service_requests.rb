class ApiController
  module ServiceRequests
    def show_service_requests
      params["filter"] ||= []
      params["filter"] << "requester_id=#{@auth_user_obj.id}"
      show_generic(:service_requests)
    end

    #
    # Service Requests Subcollection Supporting Methods
    #
    def service_requests_query_resource(object)
      klass = collection_class(:service_requests)
      object ? klass.where(:source_id => object.id) : {}
    end
  end
end
