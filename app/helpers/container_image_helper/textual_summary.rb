module ContainerImageHelper
  module TextualSummary
    #
    # Groups
    #

    def textual_group_properties
      items = %w(name tag id)
      items.collect { |m| send("textual_#{m}") }
    end

    def textual_group_relationships
      items = %w(containers container_image_registry ems)
      items.collect { |m| send("textual_#{m}") }
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
