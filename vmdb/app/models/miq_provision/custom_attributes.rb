module MiqProvision::CustomAttributes
  def set_miq_custom_attributes(vm, custom_attrs)
    return if custom_attrs.blank?

    log_header = "MIQ(#{self.class.name}#set_miq_custom_attributes)"
    begin
      attrs = []
      custom_attrs.each do |k, v|
        $log.info("#{log_header} Setting EVM Custom Attribute key=#{k.to_s.inspect}, value=#{v.inspect}")
        attrs << {:name => k.to_s, :value => v, :source => "EVM"}
      end
      vm.custom_attributes.create(attrs)
    rescue => err
      $log.warn "#{log_header} Failed to set EVM Custom Attributes #{custom_attrs.inspect}.  Reason:<#{err}>"
    end
  end

  def set_ems_custom_attributes(vm, custom_attrs)
    return if custom_attrs.blank?

    log_header = "MIQ(#{self.class.name}#set_ems_custom_attributes)"
    custom_attrs.each do |k, v|
      begin
        $log.info("#{log_header} Setting EMS Custom Attribute key=#{k.to_s.inspect}, value=#{v.to_s.inspect}")
        vm.set_custom_field(k.to_s, v.to_s)
      rescue => err
        $log.warn "#{log_header} Failed to set EMS Custom Attribute <#{k}> to <#{v}>.  Reason:<#{err}>"
      end
    end
  end
end
