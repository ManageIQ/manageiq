module WSAttributeMixin

  def ws_attributes
    results = []
    web_service_skip_attrs = ['memory_exceeds_current_host_headroom']

    self.class.virtual_columns_hash.collect do |k, v|
      next if web_service_skip_attrs.include?(k)
      next if k.include?("password")
      next if k =~ /custom_\d/

      if k == 'id' || k.ends_with?('_id')
        type = :string
      else
        type = case v.type
        when :string_set  then :array_of_string
        # Use :float for numeric values because :integer will not support
        # Bignum values and will generate invalid XML
        when :numeric_set then :array_of_numeric
        when :integer     then :integer
        when :symbol      then :string
        when :timestamp   then :datetime
        else v.type
        end
      end

      result = {
        :name      => k,
        :data_type => type,
        :value     => type.to_s.include?('array') ? self.send(k).join('|') : self.send(k)
      }

      results << result
    end
    results
  end

end
