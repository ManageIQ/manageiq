module ContainerImageHelper
  module TextualSummary
    #
    # Groups
    #

    def textual_group_properties
      %i(name tag id full_name)
    end

    def textual_group_relationships
      %i(containers container_image_registry ems)
    end

    def textual_group_smart_management
      items = %w(tags)
      items.collect { |m| send("textual_#{m}") }.flatten.compact
    end

    def textual_group_packages
      labels = [_("Name"), _("Version"), _("Release"), _("Arch")]
      h = {:labels => labels}
      h[:values] = @record.guest_applications.collect do |package|
        [
          package.name,
          package.version,
          package.release,
          package.arch
        ]
      end
      h
    end

    #
    # Items
    #

    def textual_name
      @record.name
    end

    def textual_tag
      @record.tag
    end

    def textual_id
      {:label => "Image Id", :value => @record.image_ref}
    end

    def textual_full_name
      {:label => "Full Name", :value => @record.full_name}
    end
  end
end
