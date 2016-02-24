module ContainerImageHelper
  module TextualSummary
    #
    # Groups
    #

    def textual_group_properties
      %i(name tag id full_name os_distribution product_type product_name)
    end

    def textual_group_relationships
      %i(ems container_image_registry container_projects container_groups containers container_nodes)
    end

    def textual_group_configuration
      %i(guest_applications)
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
  end
end
