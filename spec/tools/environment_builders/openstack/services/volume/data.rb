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

        def volume_name_2
          "EmsRefreshSpec-Volume-2"
        end

        def volume_name_3
          "EmsRefreshSpec-Volume-3"
        end

        def volume_name_4
          "EmsRefreshSpec-Volume-4"
        end

        def volume_name_5
          "EmsRefreshSpec-Volume-5"
        end

        def volume_snapshot_name_1
          "EmsRefreshSpec-VolumeSnapshot"
        end

        def volume_snapshot_name_2
          "EmsRefreshSpec-VolumeSnapshot_0_2"
        end

        def volume_snapshot_name_3
          "EmsRefreshSpec-VolumeSnapshot_0_3"
        end

        def volume_types
          [{:name => volume_type_name_1}, {:name => volume_type_name_2}, {:name => 'random'}]
        end

        def volumes(volume_type_name = nil)
          volumes = {
            volume_type_name_2 => [
              {
                :name        => volume_name_1,
                :description => "EmsRefreshSpec-Volume description",
                :size        => 1
              }, {
                :name        => volume_name_2,
                :description => "EmsRefreshSpec-Volume description",
                :size        => 1
              }, {
                :name         => volume_name_3,
                :__image_name => "EmsRefreshSpec-Image",
                :description  => "EmsRefreshSpec-Volume description",
                :size         => 1
              }, {
                :name         => volume_name_4,
                :__image_name => "EmsRefreshSpec-Image",
                :description  => "EmsRefreshSpec-Volume description",
                :size         => 1
              }, {
                :name        => volume_name_5,
                :description => "EmsRefreshSpec-Volume description",
                :size        => 1
              }]}

          indexed_collection_return(volumes, volume_type_name)
        end

        def volume_snapshots(volume_name = nil)
          volume_snapshots = {
            volume_name_1 => [
              {
                :name        => volume_snapshot_name_1,
                :description => "EmsRefreshSpec-VolumeSnapshot description"
              }, {
                :name        => volume_snapshot_name_2,
                :description => "EmsRefreshSpec-VolumeSnapshot description"
              }, {
                :name        => volume_snapshot_name_3,
                :description => "EmsRefreshSpec-VolumeSnapshot description"
              }]}

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
