module ContainerImageRegistryHelper
  module TextualSummary
    #
    # Groups
    #

    def textual_group_properties
      items = %w(host port)
      items.collect { |m| send("textual_#{m}") }
    end

    def textual_group_relationships
      items = %w(container_images containers ems)
      items.collect { |m| send("textual_#{m}") }
    end

    #
    # Items
    #

    def textual_host
      {:label => "host", :value => @record.host}
    end

    def textual_port
      {:label => "port", :value => @record.port}
    end
  end
end
