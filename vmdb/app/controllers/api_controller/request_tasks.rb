class ApiController
  module RequestTasks
    #
    # Tasks/Request Tasks Subcollection Supporting Methods
    #
    def request_tasks_query_resource(object)
      klass = collection_config[:request_tasks][:klass].constantize
      object ? klass.where(:miq_request_id => object.id) : {}
    end

    alias_method :tasks_query_resource, :request_tasks_query_resource
  end
end
