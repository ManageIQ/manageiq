class MiqPolicyContent < ApplicationRecord
  include SeedingMixin

  belongs_to :miq_policy
  belongs_to :miq_event_definition
  belongs_to :miq_action

  def self.search_filter_from_hash(hash)
    {
      :miq_policy           => MiqPolicy.find_by_guid(hash.delete(:miq_policy_guid)),
      :miq_action           => MiqAction.find_by_name(hash.delete(:miq_action_name)),
      :miq_event_definition => MiqEventDefinition.find_by_name(hash.delete(:miq_event_definition_name))
    }
  end

  def self.seed
    seed_model(
      self,
      :find_by => method(:search_filter_from_hash)
    )
  end

  def get_action(qualifier = nil)
    action = miq_action

    # set a default value of true for the synchronous flag if it's nil
    self.success_synchronous  = true if success_synchronous.nil?
    self.failure_synchronous  = true if failure_synchronous.nil?
    action.synchronous        = true if action.synchronous.nil?

    case qualifier.to_s
    when 'success'
      action.sequence    = success_sequence
      action.synchronous = success_synchronous
    when 'failure'
      action.sequence    = failure_sequence
      action.synchronous = failure_synchronous
    end
    action
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on", "miq_policy_id", "miq_event_definition_id", "miq_action_id"].each { |k| h.delete(k) }
    h.delete_if { |_k, v| v.nil? }
    h["MiqEventDefinition"]  = miq_event_definition.export_to_array.first["MiqEventDefinition"]
    h["MiqAction"] = miq_action.export_to_array.first["MiqAction"] if miq_action
    [self.class.to_s => h]
  end
end
