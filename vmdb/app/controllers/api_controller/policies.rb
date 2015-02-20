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

    def policies_assign_resource(object, _type, id = nil, data = nil)
      policy_assign_action(object, :policies, id, data)
    end

    def policies_unassign_resource(object, _type, id = nil, data = nil)
      policy_unassign_action(object, :policies, id, data)
    end

    def policy_profiles_assign_resource(object, _type, id = nil, data = nil)
      policy_assign_action(object, :policy_profiles, id, data)
    end

    def policy_profiles_unassign_resource(object, _type, id = nil, data = nil)
      policy_unassign_action(object, :policy_profiles, id, data)
    end

    private

    def policy_ident(ctype, policy)
      cdesc = (ctype == :policies) ? "Policy" : "Policy Profile"
      "#{cdesc}: id:'#{policy.id}' description:'#{policy.description}' guid:'#{policy.guid}'"
    end

    def object_policies(object)
      policy_klass = collection_config[:policies][:klass].constantize
      object.get_policies.select { |p| p.kind_of?(policy_klass) }
    end

    def policy_specified(id, data, collection, klass)
      return klass.find(id) if id.to_i > 0
      parse_policy(data, collection, klass)
    end

    def parse_policy(data, collection, klass)
      return {} if data.blank?

      guid = data["guid"]
      return klass.find_by_guid(guid) if guid.present?

      href = data["href"]
      href.match(%r{^.*/#{collection}/[0-9]+$}) ? klass.find(href.split('/').last) : {}
    end

    def policy_subcollection_action(ctype, policy)
      if policy.present?
        result = yield if block_given?
      else
        result = action_result(false, "Must specify a valid #{ctype} href or guid")
      end

      add_parent_href_to_result(result)
      add_policy_to_result(result, ctype, policy)
      log_result(result)
      result
    end

    def policy_assign_action(object, ctype, id, data)
      klass  = collection_config[ctype][:klass].constantize
      policy = policy_specified(id, data, ctype, klass)
      policy_subcollection_action(ctype, policy) do
        api_log_info("Assigning #{policy_ident(ctype, policy)}")
        policy_assign(object, ctype, policy)
      end
    end

    def policy_unassign_action(object, ctype, id, data)
      klass  = collection_config[ctype][:klass].constantize
      policy = policy_specified(id, data, ctype, klass)
      policy_subcollection_action(ctype, policy) do
        api_log_info("Unassigning #{policy_ident(ctype, policy)}")
        policy_unassign(object, ctype, policy)
      end
    end

    def policy_assign(object, ctype, policy)
      object.add_policy(policy)
      action_result(true, "Assigning #{policy_ident(ctype, policy)}")
    rescue => err
      action_result(false, err.to_s)
    end

    def policy_unassign(object, ctype, policy)
      object.remove_policy(policy)
      action_result(true, "Unassigning #{policy_ident(ctype, policy)}")
    rescue => err
      action_result(false, err.to_s)
    end
  end
end
