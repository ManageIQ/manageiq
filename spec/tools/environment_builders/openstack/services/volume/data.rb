require_relative '../base_data'

module Openstack
  module Services
    module Volume
      class Data < ::Openstack::Services::BaseData
        def volume_type_name_1
          "EmsRefreshSpec-VolumeType"
        end

        def volume_type_name_2
          "iscsi"
        end

        def volume_name_1
          "EmsRefreshSpec-Volume"
        end

        def volume_snapshot_name_1
          "EmsRefreshSpec-VolumeSnapshot"
        end

        def volume_types
          [{:name => volume_type_name_1}, {:name => volume_type_name_2}]
        end

        def volumes(volume_type_name = nil)
          volumes = {
            volume_type_name_2 => [{
              :name         => volume_name_1,
              :__image_name => "EmsRefreshSpec-Image",
              :description  => "EmsRefreshSpec-Volume description",
              :size         => 1}]}

          indexed_collection_return(volumes, volume_type_name)
        end

        def volume_snapshots(volume_name = nil)
          volume_snapshots = {
            volume_name_1  => [{
              :name        => volume_snapshot_name_1,
              :description => "EmsRefreshSpec-VolumeSnapshot description"}]}

          indexed_collection_return(volume_snapshots, volume_name)
        end

        def volumes_from_snapshots(volume_snapshot_name = nil)
          volumes_from_snapshots = {
            volume_snapshot_name_1 => [{
              :name        => "EmsRefreshSpec-Volume-FromSnapshot",
              :description => "EmsRefreshSpec-Volume-FromSnapshot description"}]}

          indexed_collection_return(volumes_from_snapshots, volume_snapshot_name)
        end
      end
    end
  end
end
