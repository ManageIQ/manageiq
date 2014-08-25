module ServiceHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w(name description guid)
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_vm_totals
    items = %w{aggregate_all_vm_cpus aggregate_all_vm_memory
                aggregate_all_vm_disk_count aggregate_all_vm_disk_space_allocated
                aggregate_all_vm_disk_space_used aggregate_all_vm_memory_on_disk}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_lifecycle
    items = %w{retirement_date owner group created}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w(catalog_item parent_service)
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_tags
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_miq_custom_attributes
    items = %w(miq_custom_attributes)
    ret = items.collect { |m| send("textual_#{m}") }.flatten.compact
    ret.blank? ? nil : ret
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_description
    {:label => "Description", :value => @record.description}
  end

  def textual_guid
    {:label => "Management Engine GUID", :value => @record.guid}
  end

  def textual_aggregate_all_vm_cpus
    {:label => "CPU", :value => @record.aggregate_all_vm_cpus }
  end

  def textual_aggregate_all_vm_memory
    {:label => "Memory", :value => number_to_human_size(@record.aggregate_all_vm_memory.megabytes, :precision => 2) }
  end

  def textual_aggregate_all_vm_disk_count
    {:label => "Disk Count", :value => @record.aggregate_all_vm_disk_count }
  end

  def textual_aggregate_all_vm_disk_space_allocated
    {:label => "Disk Space Allocated", :value => number_to_human_size(@record.aggregate_all_vm_disk_space_allocated,:precision=>2) }
  end

  def textual_aggregate_all_vm_disk_space_used
    {:label => "Disk Space Used", :value => number_to_human_size(@record.aggregate_all_vm_disk_space_used,:precision=>2) }
  end

  def textual_aggregate_all_vm_memory_on_disk
    {:label => "Memory on Disk", :value => number_to_human_size(@record.aggregate_all_vm_memory_on_disk, :precision => 2) }
  end

  def textual_retirement_date
    {:label => "Retirement Date", :image => "retirement", :value => (@record.retires_on.nil? ? "Never" : @record.retires_on.to_time.strftime("%x"))}
  end

  def textual_catalog_item
    #{:label => "Parent Catalog Item", :value => @record.service_template.name }
    st = @record.service_template
    s = {:label => "Parent Catalog Item", :image => "service_template", :value => (st.nil? ? "None" : st.name)}
    if st && role_allows(:feature=>"catalog_items_accord")
      s[:title] = "Show this Service's Parent Service Catalog"
      s[:link]  = url_for(:controller => 'catalog', :action => 'show', :id => st)
    end
    s
  end

  def textual_parent_service
    parent = @record.parent_service
    {
      :label => "Parent Service",
      :image => parent.picture ? "/pictures/#{parent.picture.basename}" : 'service',
      :value => parent.name,
      :title => "Show this Service's Parent Service",
      :link  => url_for(:controller => 'service', :action => 'show', :id => parent)
    } if parent
  end

  def textual_owner
    return nil if @record.evm_owner.nil?
    {:label => "Owner", :value => @record.evm_owner.name}
  end

  def textual_group
    return nil if @record.miq_group.nil?
    {:label => "Group", :value => @record.miq_group.description}
  end

  def textual_created
    {:label => "Created On", :value => format_timezone(@record.created_at)}
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end

  def textual_miq_custom_attributes
    attrs = @record.miq_custom_attributes
    return nil if attrs.blank?
    attrs.collect { |a| {:label => a.name, :value => a.value} }
  end
end
