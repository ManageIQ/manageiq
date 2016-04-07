module ContainerImageHelper
  module TextualSummary
    #
    # Groups
    #

    def textual_group_properties
      %i(name tag id full_name os_distribution product_type product_name)
    end

    def textual_group_compliance
      %i(compliance_status compliance_history)
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
      h = {:label => _("History")}
      if @record.number_of(:compliances) == 0
        h[:value] = _("Not Available")
      else
        h[:image] = "compliance"
        h[:value] = _("Available")
        h[:title] = _("Show Compliance History of this Container Image (Last 10 Checks)")
        h[:explorer] = true
        h[:link] = url_for(
          :controller => controller.controller_name,
          :action     => 'show',
          :id         => @record,
          :display    => 'compliance_history')
      end
      h
    end
  end
end
