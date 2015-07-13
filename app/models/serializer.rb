class Serializer
  private

  def included_attributes(attributes)
    attributes.reject { |key, _| self.class::EXCLUDED_ATTRIBUTES.include?(key) }
  end
end
