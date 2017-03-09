class RenameContainerLabelTagMapping < ActiveRecord::Migration[5.0]
  class MappableEntity < ActiveRecord::Base; end
  class ProviderLabelTagMapping < ActiveRecord::Base; end

  def change
    create_table :mappable_entities do |t|
      t.string :name,          :comment => "The name of the mappable resource type."
      t.string :provider,      :comment => "The provider name associated with the resource type."
      t.string :manager_type,  :comment => "The full class name of the resource type."
    end

    # Add the current default list of mappable entities currently defined by
    # the ContainerLabelTagMapping::MAPPABLE_ENTITIES array.
    %w[
      ContainerProject
      ContainerRoute
      ContainerNode
      ContainerReplicator
      ContainerService
      ContainerGroup
      ContainerBuild
    ].each do |entity|
      MappableEntity.create!(
        :name         => entity,
        :provider     => 'kubernetes',
        :manager_type => 'ManageIQ::Providers::Kubernetes::ContainerManager::' + entity
      )
    end

    MappableEntity.create!(
      :name         => 'VmOrTemplate',
      :provider     => 'amazon',
      :manager_type => 'ManageIQ::Providers::Amazon::CloudManager::VmOrTemplate'
    )

    rename_table :container_label_tag_mappings, :provider_label_tag_mappings
    add_column :provider_label_tag_mappings, :mappable_entity_id, :integer

    ProviderLabelTagMapping.find_each do |mapping|
      name = mapping.labeled_resource_type
      mapping.mappable_entity_id = MappableEntity.find_by_name(name).id if name
      mapping.save!
    end

    remove_column :provider_label_tag_mappings, :labeled_resource_type, :string
  end
end
