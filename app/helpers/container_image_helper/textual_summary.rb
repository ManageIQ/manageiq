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

    #
    # Items
    #

    def textual_name
      {:label => "Name", :value => @record.name}
    end

    def textual_tag
      {:label => "Tag", :value => @record.tag}
    end

    def textual_id
      {:label => "Image Id", :value => @record.image_ref}
    end

    def textual_full_name
      {:label => "Full Name", :value => @record.full_name}
    end
  end
end
