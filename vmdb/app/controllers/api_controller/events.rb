class ApiController
  module Events
    #
    # Events Subcollection Supporting Methods
    #

    def events_query_resource(object)
      return {} unless object && object.respond_to?(:events)
      object.events
    end
  end
end
