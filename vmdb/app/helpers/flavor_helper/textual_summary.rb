module FlavorHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w(cpus cpu_cores memory supports_32_bit supports_64_bit supports_hvm supports_paravirtual)
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{ems_cloud instances}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_tags
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_memory
    {:label => "Memory", :value => @record.memory ? number_to_human_size(@record.memory, :precision=>1) : ""}
  end

  def textual_cpus
    {:label => "CPUs", :value => @record.cpus}
  end

  def textual_cpu_cores
    {:label => "CPU Cores", :value => @record.cpu_cores}
  end

  def textual_supports_32_bit
    return nil if @record.kind_of?(FlavorOpenstack) || @record.supports_32_bit.nil?
    {:label => "32 Bit Architecture ", :value => @record.supports_32_bit?}
  end

  def textual_supports_64_bit
    return nil if @record.kind_of?(FlavorOpenstack) || @record.supports_64_bit.nil?
    {:label => "64 Bit Architecture ", :value => @record.supports_64_bit?}
  end

  def textual_supports_hvm
    return nil if @record.kind_of?(FlavorOpenstack) || @record.supports_hvm.nil?
    {:label => "HVM (Hardware Virtual Machine)", :value => @record.supports_hvm?}
  end

  def textual_supports_paravirtual
    return nil if @record.kind_of?(FlavorOpenstack) || @record.supports_paravirtual.nil?
    {:label => "Paravirtualization", :value => @record.supports_paravirtual?}
  end

  def textual_ems_cloud
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_cloud")
    h = {:label => label, :image => "vendor-#{ems.emstype.downcase}", :value => ems.name}
    if role_allows(:feature => "ems_cloud_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_cloud', :action => 'show', :id => ems)
    end
    h
  end

  def textual_instances
    label = ui_lookup(:tables=>"vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @flavor, :display => 'instances')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.blank?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end
end
