module AvailabilityZoneHelper::TextualSummary
  include TextualMixins::TextualEmsCloud
  include TextualMixins::TextualGroupTags
  #
  # Groups
  #

  def textual_group_relationships
    %i(ems_cloud instances cloud_volumes)
  end

  def textual_group_availability_zone_totals
    %i(block_storage_disk_capacity block_storage_disk_usage)
  end

  #
  # Items
  #

  def textual_cloud_volumes
    label = ui_lookup(:tables => "cloud_volume")
    num   = @record.number_of(:cloud_volumes)
    h     = {:label => label, :image => "100/cloud_volume.png", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_volume_show_list")
      h[:link]  = url_for(:action => 'show', :id => @availability_zone, :display => 'cloud_volumes')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @availability_zone, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_block_storage_disk_capacity
    return nil unless @record.respond_to?(:block_storage_disk_capacity) && !@record.ext_management_system.provider.nil?
    {:value => number_to_human_size(@record.block_storage_disk_capacity.gigabytes, :precision => 2)}
  end

  def textual_block_storage_disk_usage
    return nil unless @record.respond_to?(:block_storage_disk_usage)
    {:value => number_to_human_size(@record.block_storage_disk_usage.bytes, :precision => 2)}
  end
end
