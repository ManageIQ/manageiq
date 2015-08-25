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
  end
end
