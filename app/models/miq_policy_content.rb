class MiqPolicyContent < ActiveRecord::Base
  belongs_to :miq_policy
  belongs_to :miq_event_definition
  belongs_to :miq_action

  def get_action(qualifier = nil)
    action = self.miq_action

    # set a default value of true for the synchronous flag if it's nil
    self.success_synchronous  = true if self.success_synchronous.nil?
    self.failure_synchronous  = true if self.failure_synchronous.nil?
    action.synchronous        = true if action.synchronous.nil?

    case qualifier.to_s
    when 'success'
      action.sequence    = self.success_sequence
      action.synchronous = self.success_synchronous
    when 'failure'
      action.sequence    = self.failure_sequence
      action.synchronous = self.failure_synchronous
    end
    return action
  end

  def export_to_array
    h = self.attributes
    ["id", "created_on", "updated_on", "miq_policy_id", "miq_event_definition_id", "miq_action_id"].each { |k| h.delete(k) }
    h.delete_if { |k,v| v.nil? }
    h["MiqEventDefinition"]  = self.miq_event_definition.export_to_array.first["MiqEventDefinition"]
    h["MiqAction"] = self.miq_action.export_to_array.first["MiqAction"] if self.miq_action
    return [ self.class.to_s => h ]
  end
end
