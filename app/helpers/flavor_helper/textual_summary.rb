module FlavorHelper::TextualSummary
  include TextualMixins::TextualEmsCloud
  include TextualMixins::TextualGroupTags
  #
  # Groups
  #

  def textual_group_properties
    %i(
      cpus
      cpu_cores
      memory
      supports_32_bit
      supports_64_bit
      supports_hvm
      supports_paravirtual
      block_storage_based_only
      cloud_subnet_required
    )
  end

  def textual_group_relationships
    %i(ems_cloud instances)
  end

  #
  # Items
  #

  def textual_memory
    @record.memory && number_to_human_size(@record.memory, :precision => 1)
  end

  def textual_cpus
    {:label => _("CPUs"), :value => @record.cpus}
  end

  def textual_cpu_cores
    {:label => _("CPU Cores"), :value => @record.cpu_cores}
  end

  def textual_supports_32_bit
    return nil if @record.supports_32_bit.nil?
    {:label => _("32 Bit Architecture"), :value => @record.supports_32_bit?}
  end

  def textual_supports_64_bit
    return nil if @record.supports_64_bit.nil?
    {:label => _("64 Bit Architecture"), :value => @record.supports_64_bit?}
  end

  def textual_supports_hvm
    return nil if @record.supports_hvm.nil?
    {:label => _("HVM (Hardware Virtual Machine)"), :value => @record.supports_hvm?}
  end

  def textual_supports_paravirtual
    return nil if @record.supports_paravirtual.nil?
    {:label => _("Paravirtualization"), :value => @record.supports_paravirtual?}
  end

  def textual_block_storage_based_only
    return nil if @record.block_storage_based_only.nil?
    {:label => _("Block Storage Based"), :value => @record.block_storage_based_only?}
  end

  def textual_cloud_subnet_required
    @record.cloud_subnet_required?
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end
end
