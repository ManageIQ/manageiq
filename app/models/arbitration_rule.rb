class ArbitrationRule < ApplicationRecord
  ALLOWED_OPERATIONS = %w(inject disable_engine auto_reject require_approval auto_approve).freeze
  FIELD_OBJECTS = %w(User Blueprint ServiceTemplate).freeze
  validates :operation, :inclusion => { :in => ALLOWED_OPERATIONS }
  validates :expression, :presence => true

  serialize :expression

  def self.get_by_rule_class(rule_class)
    where('expression like ?', "%#{rule_class}%").order(:priority)
  end

  def self.field_values
    FIELD_OBJECTS.flat_map do |object|
      object.constantize.attribute_names.flat_map { |attribute| "#{object}-#{attribute}" }
    end
  end
end
