module ServiceHelper::TextualSummary
  include TextualMixins::TextualDescription
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName
  #
  # Groups
  #

  def textual_group_properties
    %i(name description guid)
  end

  def textual_group_vm_totals
    %i(aggregate_all_vm_cpus aggregate_all_vm_memory
       aggregate_all_vm_disk_count aggregate_all_vm_disk_space_allocated
       aggregate_all_vm_disk_space_used aggregate_all_vm_memory_on_disk)
  end

  def textual_group_lifecycle
    %i(retirement_date retirement_state owner group created)
  end

  def textual_group_relationships
    %i(catalog_item parent_service orchestration_stack job)
  end

  def textual_group_miq_custom_attributes
    textual_miq_custom_attributes
  end

  #
  # Items
  #
  def textual_guid
    {:label => _("Management Engine GUID"), :value => @record.guid}
  end

  def textual_aggregate_all_vm_cpus
    {:label => _("CPU"), :value => @record.aggregate_all_vm_cpus}
  end

  def textual_aggregate_all_vm_memory
    {:label => _("Memory"), :value => number_to_human_size(@record.aggregate_all_vm_memory.megabytes, :precision => 2)}
  end

  def textual_aggregate_all_vm_disk_count
    {:label => _("Disk Count"), :value => @record.aggregate_all_vm_disk_count}
  end

  def textual_aggregate_all_vm_disk_space_allocated
    {:label => _("Disk Space Allocated"),
     :value => number_to_human_size(@record.aggregate_all_vm_disk_space_allocated, :precision => 2)}
  end

  def textual_aggregate_all_vm_disk_space_used
    {:label => _("Disk Space Used"),
     :value => number_to_human_size(@record.aggregate_all_vm_disk_space_used, :precision => 2)}
  end

  def textual_aggregate_all_vm_memory_on_disk
    {:label => _("Memory on Disk"),
     :value => number_to_human_size(@record.aggregate_all_vm_memory_on_disk, :precision => 2)}
  end

  def textual_retirement_date
    {:label => _("Retirement Date"),
     :image => "retirement",
     :value => (@record.retires_on.nil? ? _("Never") : @record.retires_on.strftime("%x %R %Z"))}
  end

  def textual_retirement_state
    {:label => _("Retirement State"), :value => @record.retirement_state.to_s.capitalize}
  end

  def textual_catalog_item
    st = @record.service_template
    s = {:label => _("Parent Catalog Item"), :image => "service_template", :value => (st.nil? ? _("None") : st.name)}
    if st && role_allows?(:feature => "catalog_items_accord")
      s[:title] = _("Show this Service's Parent Service Catalog")
      s[:link]  = url_for(:controller => 'catalog', :action => 'show', :id => st)
    end
    s
  end

  def textual_parent_service
    parent = @record.parent_service
    {
      :label => _("Parent Service"),
      :image => parent.picture ? "/pictures/#{parent.picture.basename}" : 'service',
      :value => parent.name,
      :title => _("Show this Service's Parent Service"),
      :link  => url_for(:controller => 'service', :action => 'show', :id => parent)
    } if parent
  end

  def textual_orchestration_stack
    ost = @record.try(:orchestration_stack)
    {
      :label => _("Stack"),
      :image => "orchestration_stack",
      :value => ost.name,
      :title => _("Show this Service's Stack"),
      :link  => url_for(:controller => 'orchestration_stack', :action => 'show', :id => ost.id)
    } if ost
  end

  def textual_job
    job = @record.try(:job)
    {
      :label => _("Job"),
      :image => "orchestration_stack",
      :value => job.name,
      :title => _("Show this Service's Job"),
      :link  => url_for(:controller => 'configuration_job', :action => 'show', :id => job.id)
    } if job
  end

  def textual_owner
    @record.evm_owner.try(:name)
  end

  def textual_group
    @record.miq_group.try(:description)
  end

  def textual_created
    {:label => _("Created On"), :value => format_timezone(@record.created_at)}
  end

  def textual_miq_custom_attributes
    attrs = @record.miq_custom_attributes
    return nil if attrs.blank?
    attrs.collect { |a| {:label => a.name, :value => a.value} }
  end
end
