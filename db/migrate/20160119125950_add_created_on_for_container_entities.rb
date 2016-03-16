class AddCreatedOnForContainerEntities < ActiveRecord::Migration
  class ContainerNode < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class ContainerProject < ActiveRecord::Base; end

  class ContainerService < ActiveRecord::Base; end

  class ContainerRoute < ActiveRecord::Base; end

  class ContainerGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class ContainerReplicator < ActiveRecord::Base; end

  class ContainerQuota < ActiveRecord::Base; end

  class ContainerBuild < ActiveRecord::Base; end

  class ContainerBuildPod < ActiveRecord::Base; end

  class ContainerLimit < ActiveRecord::Base; end

  class ContainerVolume < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  CONTAINER_MODELS = [ContainerNode, ContainerProject, ContainerService, ContainerRoute, ContainerGroup,
                      ContainerReplicator, ContainerQuota, ContainerBuild, ContainerBuildPod, ContainerLimit,
                      ContainerVolume].freeze

  def change
    CONTAINER_MODELS.each do |model|
      add_column model.table_name, :created_on, :datetime
      rename_column model.table_name, :creation_timestamp, :ems_created_on

      say_with_time("adding created_on datetime to all existing #{model}") do
        model.update_all("created_on=ems_created_on")
      end
    end
  end
end
