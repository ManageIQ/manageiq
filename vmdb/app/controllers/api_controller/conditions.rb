class ApiController
  module Conditions
    #
    # Conditions Subcollection Supporting Methods
    #

    def conditions_query_resource(object)
      return {} unless object && object.respond_to?(:conditions)
      object.conditions
    end
  end
end
