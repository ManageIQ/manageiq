module ContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name state reason started_at finished_at exit_code signal message last_state restart_count backing_ref command
       capabilities_add capabilities_drop privileged run_as_user se_linux_user se_linux_role se_linux_type
       se_linux_level run_as_non_root)
  end

  def textual_group_relationships
    %i(ems container_project container_replicator container_group container_node container_image)
  end

  def textual_group_smart_management
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_state
    @record.state
  end

  def textual_reason
    {:label => _("Reason"), :value => @record.reason} if @record.reason
  end

  def textual_started_at
    {:label => _("Started At"), :value => @record.started_at} if @record.started_at
  end

  def textual_finished_at
    {:label => _("Finished At"), :value => @record.finished_at} if @record.finished_at
  end

  def textual_exit_code
    {:label => _("Exit Code"), :value => @record.exit_code} if @record.exit_code
  end

  def textual_signal
    {:label => _("Signal"), :value => @record.signal} if @record.signal
  end

  def textual_message
    {:label => _("Message"), :value => @record.message} if @record.message
  end

  def textual_last_state
    {:label => _("Last State"), :value => @record.last_state}
  end

  def textual_restart_count
    @record.restart_count
  end

  def textual_backing_ref
    {:label => _("Backing Ref (Container ID)"), :value => @record.backing_ref}
  end

  def textual_command
    {:label => _("Command"), :value => @record.container_definition.command} if @record.container_definition.command
  end

  def textual_capabilities_add
    unless @record.container_definition.capabilities_add.empty?
      {:label => _("Add Capabilities"),
       :value => @record.container_definition.capabilities_add}
    end
  end

  def textual_capabilities_drop
    unless @record.container_definition.capabilities_drop.empty?
      {:label => _("Drop Capabilities"),
       :value => @record.container_definition.capabilities_drop}
    end
  end

  def textual_privileged
    {:label => _("Privileged"),
     :value => @record.container_definition.privileged} unless @record.container_definition.privileged.nil?
  end

  def textual_run_as_user
    {:label => _("Run As User"),
     :value => @record.container_definition.run_as_user} if @record.container_definition.run_as_user
  end

  def textual_se_linux_user
    se_linux_user = @record.security_context.try(:se_linux_user)
    {:label => _("SELinux User"), :value => se_linux_user} if se_linux_user
  end

  def textual_se_linux_role
    se_linux_role = @record.security_context.try(:se_linux_role)
    {:label => _("SELinux Role"), :value => se_linux_role} if se_linux_role
  end

  def textual_se_linux_type
    se_linux_type = @record.security_context.try(:se_linux_type)
    {:label => _("SELinux Type"), :value => se_linux_type} if se_linux_type
  end

  def textual_se_linux_level
    se_linux_level = @record.security_context.try(:se_linux_level)
    {:label => _("SELinux Level"), :value => se_linux_level} if se_linux_level
  end

  def textual_run_as_non_root
    {:label => _("Run As Non Root"),
     :value => @record.container_definition.run_as_non_root} unless @record.container_definition.run_as_non_root.nil?
  end

  def textual_group_env
    {
      :additional_table_class => "table-fixed",
      :labels                 => [_("Name"), _("Type"), _("Value")],
      :values                 => collect_env
    }
  end

  def collect_env_variables
    @record.container_definition.container_env_vars.collect do |var|
      [var.name, var.value, var.field_path]
    end
  end
end
