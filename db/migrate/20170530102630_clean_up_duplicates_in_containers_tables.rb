class CleanUpDuplicatesInContainersTables < ActiveRecord::Migration[5.0]
  class ContainerBuild < ActiveRecord::Base; end
  class ContainerBuildPod < ActiveRecord::Base; end
  class ContainerGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end
  class ContainerLimit < ActiveRecord::Base; end
  class ContainerNode < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end
  class ContainerProject < ActiveRecord::Base; end
  class ContainerQuota < ActiveRecord::Base; end
  class ContainerReplicator < ActiveRecord::Base; end
  class ContainerRoute < ActiveRecord::Base; end
  class ContainerService < ActiveRecord::Base; end
  class ContainerTemplate < ActiveRecord::Base; end
  class PersistentVolumeClaim < ActiveRecord::Base; end

  class ContainerComponentStatus < ActiveRecord::Base; end
  class ContainerImage < ActiveRecord::Base; end
  class ContainerImageRegistry < ActiveRecord::Base; end

  class ContainerCondition < ActiveRecord::Base; end
  class SecurityContext < ActiveRecord::Base; end
  class ContainerEnvVar < ActiveRecord::Base; end
  class ContainerLimitItem < ActiveRecord::Base; end
  class ContainerPortConfig < ActiveRecord::Base; end
  class ContainerQuotaItem < ActiveRecord::Base; end
  class ContainerServicePortConfig < ActiveRecord::Base; end
  class ContainerTemplateParameter < ActiveRecord::Base; end
  class ContainerVolume < ActiveRecord::Base; end
  class CustomAttribute < ActiveRecord::Base; end

  class ContainerDefinition < ActiveRecord::Base; end
  class Container < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def duplicate_data_query_returning_batches(model, unique_index_columns)
    model.group(unique_index_columns)
         .select("#{unique_index_columns.join(", ")}, min(id) AS first_duplicate, array_agg(id) AS duplicate_ids")
         .having("COUNT(id) > 1")
  end

  def cleanup_duplicate_data_batch(model, unique_index_columns)
    duplicate_data_query_returning_batches(model, unique_index_columns).each do |duplicate|
      # TODO(lsmola) do I need to do some merging of occurrences, e.g. reconnecting metrics, events, etc.?
      # TODO(lsmola) calling .destroy so it cascade deletes will be expensive
      model.where(:id => duplicate.duplicate_ids[1..--1]).delete_all
    end
  end

  def duplicate_data_query_returning_min_id(model, unique_index_columns)
    model.group(unique_index_columns).select("min(id)")
  end

  def cleanup_duplicate_data_delete_all(model, unique_index_columns)
    model.where.not(:id => duplicate_data_query_returning_min_id(model, unique_index_columns)).delete_all
  end

  UNIQUE_INDEXES_FOR_MODELS = {
    # Just having :ems_id & :ems_ref
    ContainerBuild             => [:ems_id, :ems_ref],
    ContainerBuildPod          => [:ems_id, :ems_ref],
    ContainerGroup             => [:ems_id, :ems_ref],
    ContainerLimit             => [:ems_id, :ems_ref],
    ContainerNode              => [:ems_id, :ems_ref],
    ContainerProject           => [:ems_id, :ems_ref],
    ContainerQuota             => [:ems_id, :ems_ref],
    ContainerReplicator        => [:ems_id, :ems_ref],
    ContainerRoute             => [:ems_id, :ems_ref],
    ContainerService           => [:ems_id, :ems_ref],
    ContainerTemplate          => [:ems_id, :ems_ref],
    PersistentVolumeClaim      => [:ems_id, :ems_ref],
    # Having :ems_id but not ems_ref
    ContainerComponentStatus   => [:ems_id, :name],
    ContainerImage             => [:ems_id, :image_ref, :container_image_registry_id],
    ContainerImageRegistry     => [:ems_id, :host, :port],
    # Nested tables, not having :ems_id and the foreign_key is a part of the unique index
    ContainerCondition         => [:container_entity_id, :container_entity_type, :name],
    SecurityContext            => [:resource_id, :resource_type],
    ContainerEnvVar            => [:container_definition_id, :name, :value, :field_path],
    ContainerLimitItem         => [:container_limit_id, :resource, :item_type],
    ContainerPortConfig        => [:container_definition_id, :ems_ref],
    ContainerQuotaItem         => [:container_quota_id, :resource],
    ContainerServicePortConfig => [:container_service_id, :ems_ref, :protocol],
    ContainerTemplateParameter => [:container_template_id, :name],
    ContainerVolume            => [:parent_id, :parent_type, :name],
    CustomAttribute            => [:resource_id, :resource_type, :name, :unique_name, :section, :source],
    # Questionable
    ContainerDefinition        => [:ems_id, :ems_ref],
    Container                  => [:ems_id, :ems_ref]
  }.freeze

  def up
    UNIQUE_INDEXES_FOR_MODELS.each do |model, unique_indexes_columns|
      say_with_time("Cleanup duplicate data for model #{model}") do
        cleanup_duplicate_data_delete_all(model, unique_indexes_columns)
      end
    end
  end
end
