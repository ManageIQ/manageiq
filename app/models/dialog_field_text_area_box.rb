class DialogFieldTextAreaBox < DialogFieldTextBox
  AUTOMATE_VALUE_FIELDS = %w[required read_only visible description validator_rule validator_type].freeze
end
