module Api
  module Subcollections
    module PolicyProfiles
      def policy_profiles_query_resource(object)
        policy_profile_klass = collection_class(:policy_profiles)
        object ? object.get_policies.select { |p| p.kind_of?(policy_profile_klass) } : {}
      end

      def policy_profiles_assign_resource(object, _type, id = nil, data = nil)
        policy_assign_action(object, :policy_profiles, id, data)
      end

      def policy_profiles_unassign_resource(object, _type, id = nil, data = nil)
        policy_unassign_action(object, :policy_profiles, id, data)
      end

      def policy_profiles_resolve_resource(object, _type, id = nil, data = nil)
        policy_resolve_action(object, :policy_profiles, id, data)
      end
    end
  end
end
