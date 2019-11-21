class DialogFieldTextAreaBox < DialogFieldTextBox
  AUTOMATE_VALUE_FIELDS = %w[required read_only visible description validator_rule validator_type].freeze

  def to_ddf
    super.merge(:component => 'textarea-field')
  end
end
