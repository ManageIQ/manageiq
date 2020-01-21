class MiqPolicyContent < ApplicationRecord
  belongs_to :miq_policy
  belongs_to :miq_event_definition
  belongs_to :miq_action

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
    h["MiqEventDefinition"] = miq_event_definition.export_to_array.first["MiqEventDefinition"] if miq_event_definition
    h["MiqAction"] = miq_action.export_to_array.first["MiqAction"] if miq_action
    [self.class.to_s => h]
  end

  def self.display_name(number = 1)
    n_('Policy Content', 'Policy Contents', number)
  end
end
