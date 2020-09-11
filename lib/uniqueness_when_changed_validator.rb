#
# Validates whether the value of the specified attributes are unique across the system,
#   but only applies the validation when those attributes have changed.
#
#   See Rails uniqueness validator: https://api.rubyonrails.org/classes/ActiveRecord/Validations/ClassMethods.html#method-i-validates_uniqueness_of
class UniquenessWhenChangedValidator < ActiveRecord::Validations::UniquenessValidator
  # Examples:
  #   validates :name, :uniqueness_when_changed => true
  def validate_each(record, attribute, value)
    return if value.nil? || !record.send("#{attribute}_changed?")

    super
  end
end
