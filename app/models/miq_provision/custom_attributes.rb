module MiqProvision::CustomAttributes
  def set_miq_custom_attributes(vm, custom_attrs)
    return if custom_attrs.blank?

    begin
      attrs = []
      custom_attrs.each do |k, v|
        _log.info("Setting EVM Custom Attribute key=#{k.to_s.inspect}, value=#{v.inspect}")
        attrs << {:name => k.to_s, :value => v, :source => "EVM"}
      end
      vm.custom_attributes.create(attrs)
    rescue => err
      _log.warn("Failed to set EVM Custom Attributes #{custom_attrs.inspect}.  Reason:<#{err}>")
    end
  end

  def set_ems_custom_attributes(vm, custom_attrs)
    return if custom_attrs.blank?

    custom_attrs.each do |k, v|
      begin
        _log.info("Setting EMS Custom Attribute key=#{k.to_s.inspect}, value=#{v.to_s.inspect}")
        vm.set_custom_field(k.to_s, v.to_s)
      rescue => err
        _log.warn("Failed to set EMS Custom Attribute <#{k}> to <#{v}>.  Reason:<#{err}>")
      end
    end
  end
end
