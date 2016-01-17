module WebServiceAttributeMixin
  def ws_attributes
    results = []
    web_service_skip_attrs = ['memory_exceeds_current_host_headroom']

    self.class.virtual_attribute_names.collect do |att|
      next if web_service_skip_attrs.include?(att)
      next if att =~ /enabled_.*ports$/
      next if att.include?("password")
      next if att =~ /custom_\d/

      if att == 'id' || att.ends_with?('_id')
        type = :string
      else
        type = self.class.type_for_attribute(att).type
        type = case type
               when :string_set  then :array_of_string
               # Use :float for numeric values because :integer will not support
               # Bignum values and will generate invalid XML
               when :numeric_set then :array_of_numeric
               when :integer     then :integer
               when :symbol      then :string
               when :timestamp   then :datetime
               else type
               end
      end

      result = {
        :name      => att,
        :data_type => type,
        :value     => type.to_s.include?('array') ? send(att).join('|') : send(att)
      }

      results << result
    end
    results
  end
end
