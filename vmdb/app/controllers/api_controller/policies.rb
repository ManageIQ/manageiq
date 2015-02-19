class ApiController
  module Policies
    #
    # Policies and Policy Profiles Subcollection Supporting Methods
    #

    def policies_query_resource(object)
      return {} unless object
      policy_profile_klass = collection_config[:policy_profiles][:klass].constantize
      (object.kind_of?(policy_profile_klass)) ? object.members : object_policies(object)
    end

    def policy_profiles_query_resource(object)
      policy_profile_klass = collection_config[:policy_profiles][:klass].constantize
      object ? object.get_policies.select { |p| p.kind_of?(policy_profile_klass) } : {}
    end

    private

    def object_policies(object)
      policy_klass = collection_config[:policies][:klass].constantize
      object.get_policies.select { |p| p.kind_of?(policy_klass) }
    end
  end
end
