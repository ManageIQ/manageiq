module ContainerImageHelper
  module TextualSummary
    #
    # Groups
    #

    def textual_group_properties
      %i(name tag id)
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
      @record.name
    end

    def textual_tag
      @record.tag
    end

    def textual_id
      {:label => "Image Id", :value => @record.image_ref}
    end
  end
end
