class ArbitrationRule < ApplicationRecord
  ALLOWED_OPERATIONS = %w(inject disable_engine auto_reject require_approval auto_approve).freeze
  # To add in a new object to be used with arbitration rules,
  # add in a static rule_attributes function to that object
  # And add it in the following array
  FIELD_OBJECTS = %w(User Blueprint ServiceTemplate).freeze
  validates :operation, :inclusion => { :in => ALLOWED_OPERATIONS }
  validates :name, :expression, :presence => true

  serialize :expression

  def self.get_by_rule_class(rule_class)
    where('expression like ?', "%#{rule_class}%").order(:priority)
  end

  def self.field_values
    fields = {}
    FIELD_OBJECTS.each do |object|
      fields[object] = object.constantize.rule_attributes
    end
    fields
  end
end
