class Serializer
  private

  def included_attributes(attributes, all_attributes = false)
    return attributes if all_attributes
    attributes.reject { |key, _| self.class::EXCLUDED_ATTRIBUTES.include?(key) }
  end
end
