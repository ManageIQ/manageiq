module ContainerImageHelper
  module TextualSummary
    #
    # Groups
    #

    def textual_group_properties
      %i(name tag id full_name os_distribution product_type product_name architecture author command entrypoint docker_version exposed_ports size)
    end

    def textual_group_relationships
      %i(ems container_image_registry container_projects container_groups containers container_nodes)
    end

    def textual_group_configuration
      %i(guest_applications openscap openscap_html last_scan)
    end

    def textual_group_smart_management
      items = %w(tags)
      items.collect { |m| send("textual_#{m}") }.flatten.compact
    end

    def textual_openscap_failed_rules
      %i(openscap_failed_rules_low openscap_failed_rules_medium openscap_failed_rules_high)
    end

    #
    # Items
    #

    def textual_tag
      @record.tag
    end

    def textual_id
      {:label => _("Image Id"), :value => @record.image_ref}
    end

    def textual_full_name
      {:label => _("Full Name"), :value => @record.full_name}
    end

    def textual_os_distribution
      distribution = @record.operating_system.try(:distribution)
      {:label => _("Operating System Distribution"), :value => distribution} if distribution
    end

    def textual_product_type
      type = @record.operating_system.try(:product_type)
      {:label => _("Product Type"), :value => type} if type
    end

    def textual_product_name
      name = @record.operating_system.try(:product_name)
      {:label => _("Product Name"), :value => name} if name
    end

    def textual_compliance_history
      super(:title    => _("Show Compliance History of this Container Image (Last 10 Checks)"),
            :explorer => true)
    end

    def failed_rules_summary
      @failed_rules_summary ||= @record.openscap_failed_rules_summary
    end

    def textual_openscap_failed_rules_low
      low = failed_rules_summary[:Low]
      {:label => _("Low"), :value => low} if low
    end

    def textual_openscap_failed_rules_medium
      medium = failed_rules_summary[:Medium]
      {:label => _("Medium"), :value => medium} if medium
    end

    def textual_openscap_failed_rules_high
      high = failed_rules_summary[:High]
      {:label => _("High"), :value => high} if high
    end

    def textual_exposed_ports
      {:label => _("Exposed Ports"),
       :value => (@record['exposed_ports'].collect { |t, p| "#{p}/#{t}" }).join(', ')
      }
    end

    def method_missing(mthd_sym, *args, &bolck)
      match = /textual_(.*)/.match(mthd_sym)
      if match && match.size > 1
        prop = match[1]
        value = @record[prop] if @record.attribute_present?(prop)
        value = value.join(' ') if value.kind_of?(Array)
        {:label => _(prop.titlecase), :value => value}
      else
        super
      end
    end
  end

  def textual_group_env
    {
      :additional_table_class => "table-fixed",
      :labels                 => [_("Name"), _("Type"), _("Value")],
      :values                 => collect_env
    }
  end

  def collect_env_variables
    @record['environment_variables'].collect do |name, value|
      [name, value, nil]
    end
  end

  def textual_group_container_docker_labels
    textual_key_value_group(@record.docker_labels.to_a)
  end
end
