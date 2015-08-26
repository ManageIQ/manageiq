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
