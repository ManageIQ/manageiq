#
# Validates that a record is unique within the region number
#
# Options:
#   :match_case: Whether or not the uniqueness check should be case sensitive
#                (default: true)
#   :scope: An attribute used to further limit the scope of the uniqueness check
#
# Examples:
#   validates :name, :unique_within_region => true
#   validates :name, :unique_within_region => {:match_case => false}
#   validates :name, :unique_within_region => {:scope => :dialog_type, :match_case => false}
#
class UniqueWithinRegionValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil? || !record.send("#{attribute}_changed?")

    match_case = options.key?(:match_case) ? options[:match_case] : true
    record_base_class = record.class.base_class
    matches =
      if match_case
        record_base_class.where(attribute => value)
      else
        record_base_class.where(record_base_class.arel_attribute(attribute).lower.eq(value.downcase))
      end
    matches = matches.where(options[:scope] => record.public_send(options[:scope])) if options.key?(:scope)
    unless matches.in_region(record.region_id).where.not(:id => record.id).empty?
      record.errors.add(attribute, "is not unique within region #{record.region_id}")
    end
  end
end
