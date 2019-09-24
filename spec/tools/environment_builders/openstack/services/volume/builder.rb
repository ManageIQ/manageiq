require_relative 'data'

module Openstack
  module Services
    module Volume
      class Builder
        attr_reader :service, :volumes, :volume_snapshots

        def self.build_all(ems, project, environment, image)
          new(ems, project, environment, image).build_all
        end

        def initialize(ems, project, environment, image)
          @service         = ems.connect(:tenant_name => project.name, :service => "Volume")
          @compute_service = ems.connect(:tenant_name => project.name)
          @data            = Data.new
          @project         = project
          @environment     = environment
          @images          = image.images

          # Collected data
          @volume_types           = []
          @volumes                = []
          @volume_snapshots       = []
          @volumes_from_snapshots = []
        end

        def build_all
          find_or_create_volume_types

          self
        end

        private

        def find_or_create_volume_types
          @data.volume_types.each do |volume_type|
            @volume_types << volume_type = find_or_create(@service.volume_types, volume_type)

            find_or_create_volumes(volume_type)
          end
        end

        def find_or_create_volumes(volume_type)
          volume_type_name = volume_type.name
          volume_type_data = @data.volumes(volume_type_name)

          return if volume_type_data.blank?

          volume_type_data.each do |volume|
            image_name = volume.delete(:__image_name)
            image_id   = @images.detect { |x| x.name == image_name }.try(:id)

            @volumes << volume = find_or_create(
              @service.volumes, volume.merge(:volume_type => volume_type_name, :imageRef => image_id))
            wait_for_volume(volume)

            find_or_create_volume_snapshots(volume)
          end
        end

        def find_or_create_volume_snapshots(volume)
          volume_data = @data.volume_snapshots(volume.name)

          return if volume_data.blank?

          volume_data.each do |volume_snapshot|
            @volume_snapshots << volume_snapshot = find_or_create(
              @compute_service.snapshots, volume_snapshot.merge(:volume_id => volume.id))

            wait_for_volume(volume_snapshot)

            find_or_create_volumes_from_snapshots(volume_snapshot)
          end
        end

        def find_or_create_volumes_from_snapshots(volume_snapshot)
          volume_from_snapshot_data = @data.volumes_from_snapshots(volume_snapshot.name)

          return if volume_from_snapshot_data.blank?

          volume_from_snapshot_data.each do |volume_from_snapshot|
            @volumes_from_snapshots << find_or_create(
              @service.volumes, volume_from_snapshot.merge(:size        => volume_snapshot.size,
                                                           :snapshot_id => volume_snapshot.id))
          end

          wait_for_volumes(@volumes_from_snapshots)
        end

        def wait_for_volumes(volumes)
          volumes.each { |volume| wait_for_volume(volume) }
        end

        def wait_for_volume(volume)
          name = volume.respond_to?(:name) ? volume.name : volume.name

          print "Waiting for volume #{name} to get in a desired state..."

          valid_states = ["available", "in-use"]
          # Seems like icehouse has not fixed bug, volume goes to error state after attaching
          # https://bugs.launchpad.net/cinder/+bug/1365234
          # TODO(lsmola) I don't think icehouse will be getting fixed, figure out we can ignore that
          # version
          valid_states << "error" if @environment == :icehouse

          loop do
            case volume.reload.status
            when *valid_states
              break
            when "error"
              puts "Error creating volume"
              exit 1
            else
              print "."
              sleep 1
            end
          end
          puts "Finished"
        end
      end
    end
  end
end
