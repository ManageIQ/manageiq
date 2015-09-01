module ContainerImageRegistryHelper
  module TextualSummary
    #
    # Groups
    #

    def textual_group_properties
      %i(host port)
    end

    def textual_group_relationships
      %i(container_images containers ems)
    end

    def textual_group_smart_management
      items = %w(tags)
      items.collect { |m| send("textual_#{m}") }.flatten.compact
    end

    #
    # Items
    #

    def textual_host
      @record.host
    end

    def textual_port
      @record.port
    end
  end
end
