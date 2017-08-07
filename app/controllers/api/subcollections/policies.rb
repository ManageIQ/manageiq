module Api
  module Subcollections
    module Policies
      def policies_query_resource(object)
        return {} unless object
        policy_profile_klass = collection_class(:policy_profiles)
        object.kind_of?(policy_profile_klass) ? object.members : object_policies(object)
      end

      def policies_assign_resource(object, _type, id = nil, data = nil)
        policy_assign_action(object, :policies, id, data)
      end

      def policies_unassign_resource(object, _type, id = nil, data = nil)
        policy_unassign_action(object, :policies, id, data)
      end

      def policies_resolve_resource(object, _type, id = nil, data = nil)
        policy_resolve_action(object, :policies, id, data)
      end

      private

      def policy_ident(ctype, policy)
        cdesc = ctype == :policies ? "Policy" : "Policy Profile"
        "#{cdesc}: id:'#{policy.id}' description:'#{policy.description}' guid:'#{policy.guid}'"
      end

      def object_policies(object)
        policy_klass = collection_class(:policies)
        object.get_policies.select { |p| p.kind_of?(policy_klass) }
      end

      def policy_specified(id, data, collection, klass)
        return klass.find(id) if id.to_i > 0
        parse_policy(data, collection, klass)
      end

      def parse_policy(data, collection, klass)
        return {} if data.blank?

        guid = data["guid"]
        return klass.find_by(:guid => guid) if guid.present?

        href = data["href"]
        if href =~ %r{^.*/#{collection}/#{ApplicationRecord::CID_OR_ID_MATCHER}$}
          klass.find(ApplicationRecord.uncompress_id(href.split('/').last))
        else
          {}
        end
      end

      def policy_subcollection_action(ctype, policy)
        if policy.present?
          result = yield if block_given?
        else
          result = action_result(false, "Must specify a valid #{ctype} href or guid")
        end

        add_parent_href_to_result(result)
        add_subcollection_resource_to_result(result, ctype, policy)
        log_result(result)
        result
      end

      def policy_assign_action(object, ctype, id, data)
        klass  = collection_class(ctype)
        policy = policy_specified(id, data, ctype, klass)
        policy_subcollection_action(ctype, policy) do
          $api_log.info("Assigning #{policy_ident(ctype, policy)}")
          policy_assign(object, ctype, policy)
        end
      end

      def policy_unassign_action(object, ctype, id, data)
        klass  = collection_class(ctype)
        policy = policy_specified(id, data, ctype, klass)
        policy_subcollection_action(ctype, policy) do
          $api_log.info("Unassigning #{policy_ident(ctype, policy)}")
          policy_unassign(object, ctype, policy)
        end
      end

      def policy_resolve_action(object, ctype, id, data)
        klass  = collection_class(ctype)
        policy = policy_specified(id, data, ctype, klass)
        policy_subcollection_action(ctype, policy) do
          $api_log.info("Resolving #{policy_ident(ctype, policy)}")
          policy_resolve(object, ctype, policy)
        end
      end

      def policy_resolve(object, ctype, policy)
        res = ctype == :policies ? object.resolve_policies([policy.name]) : object.resolve_profiles([policy.id])
        action_result(true, "Resolving #{policy_ident(ctype, policy)}", :result => res)
      rescue => err
        action_result(false, err.to_s)
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
end
