module Api
  class PoliciesController < BaseController
    include Subcollections::Conditions
    include Subcollections::Events
    include Subcollections::PolicyActions
    REQUIRED_FIELDS = %w(name description towhat conditions_ids policy_contents).freeze

    def create_resource(type, _id, data = {})
      assert_id_not_specified(data, type)
      assert_all_required_fields_exists(data, type, REQUIRED_FIELDS)
      create_policy(data)
    end

    def edit_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
      assert_all_required_fields_exists(data, type, %w(conditions_ids policy_contents))
      policy = resource_search(id, type, collection_class(:policies))
      begin
        add_policies_content(data, policy)
        policy.conditions = Condition.where(:id => data.delete("conditions_ids")) if data["conditions_ids"]
        policy.update_attributes(data)
      rescue => err
        raise BadRequestError, "Could not edit the policy - #{err}"
      end
      policy
    end

    private

    def create_policy(data)
      policy = MiqPolicy.create!(:name        => data.delete("name"),
                                 :description => data.delete("description"),
                                 :towhat      => data.delete("towhat")
                                )
      add_policies_content(data, policy)
      policy.conditions = Condition.where(:id => data.delete("conditions_ids")) if data["conditions_ids"]
      policy
    rescue => err
      policy.destroy if policy
      raise BadRequestError, "Could not create the new policy - #{err}"
    end

    def add_policies_content(data, policy)
      policy.miq_policy_contents.destroy_all
      data.delete("policy_contents").each do |policy_content|
        add_policy_content(policy_content, policy)
      end if data["policy_contents"]
    end

    def add_policy_content(policy_content, policy)
      actions_list = []
      policy_content["actions"].each do |action|
        actions_list << [MiqAction.find(action["action_id"]), action["opts"]]
      end
      policy.replace_actions_for_event(MiqEventDefinition.find(policy_content["event_id"]), actions_list)
      policy.save!
    end

    def policy_ident(policy)
      "Policy id:#{policy.id} name:'#{policy.name}'"
    end
  end
end
