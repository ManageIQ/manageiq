class ApiController
  module PolicyActions
    #
    # Policy Actions Subcollection Supporting Methods
    #

    def policy_actions_query_resource(object)
      return {} unless object && object.respond_to?(:miq_actions)
      object.miq_actions
    end
  end
end
