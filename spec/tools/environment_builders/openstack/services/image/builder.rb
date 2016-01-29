require_relative 'data'

module Openstack
  module Services
    module Image
      class Builder
        attr_reader :service, :images

        def self.build_all(ems, project)
          new(ems, project).build_all
        end

        def initialize(ems, project)
          @service = ems.connect(:tenant_name => project.name, :service => "Image")
          @data    = Data.new
          @project = project

          # Collected data
          @images = []
        end

        def build_all
          find_or_create_images

          self
        end

        def build_snapshots_from_servers(servers)
          snapshots = []
          servers.each do |server|
            next if (servers_snapshots = @data.servers_snapshots(server.name)).blank?

            servers_snapshots.each do |server_snapshot|
              image = find(@service.images, server_snapshot)
              unless image
                create(server, server_snapshot.values_at(:name), :create_image)
                # TODO(lsmola) Make fog create_image should return valid image object
                # Find created image, so it's initialized as Image object
                image = find(@service.images, server_snapshot)
              end
              snapshots << image
              @images << image
            end
          end

          wait_for_images(snapshots)
        end

        private

        def find_or_create_images
          @data.images.each do |image|
            # Uploading cirros images with redefined attributes
            @images << find_or_create(@service.images, cirros_image_data.merge(image))
          end

          # Glance v2 way of uploading image data
          @images.each do |image|
            begin
              image.upload_data(File.binread(cirros_image_data[:location]))
              puts "Uploading data for image: #{image.name}"
            rescue
              puts "Data already uploaded for image: #{image.name}"
            end
          end

          wait_for_images(@images)
        end

        def wait_for_images(images)
          images.each { |image| wait_for_image(image) }
        end

        def wait_for_image(image)
          print "Waiting for image #{image.name} to get in an 'active' state..."

          loop do
            # TODO(lsmola) identity is missing in Glance V2 object, fix it in Fog, then image.reload will work
            # case image.reload.status
            case service.images.get(image.id).status
            when "active"
              break
            when "error"
              puts "Error creating image"
              exit 1
            else
              print "."
              sleep 1
            end
          end
          puts "Finished"
        end

        def import_image
          # TODO(lsmola) do we need this? It deploys VM with blank root disk, so we can't even ssh in. So it requires
          # volume with OS
          # Based on https://github.com/fog/fog/blob/master/lib/fog/openstack/examples/image/upload-test-image.rb
          # Download CirrOS 0.3.0 image from launchpad (~6.5MB) to /tmp and upload it to Glance.
          download_image
          extract_image

          upload_aki
          upload_ari
          upload_ami
        end

        def cirros_image_data
          return @cirros_image_data unless @cirros_image_data.blank?

          image_url = "http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img"
          puts "Downloading Cirros image cirros-0.3.4-x86_64-disk.img..."
          require 'linux_admin'
          cirros_image_path = "/tmp/cirros-0.3.4-x86_64-disk#{SecureRandom.hex}.img"
          AwesomeSpawn.run!("wget -O #{cirros_image_path} #{image_url}")

          @cirros_image_data = {
            :disk_format      => 'qcow2',
            :container_format => 'bare',
            :location         => cirros_image_path
          }
        end

        def download_image
          image_url = "https://launchpadlibrarian.net/83305869/cirros-0.3.0-x86_64-uec.tar.gz"
          puts "Downloading Cirros image..."
          require 'linux_admin'
          AwesomeSpawn.run!("wget -O #{image_path} #{image_url}")
        end

        def extract_image
          FileUtils.mkdir_p extract_path
          puts "Extracting image contents to #{extract_path}..."
          AwesomeSpawn.run!("tar -zxvf #{image_path} -C #{extract_path}")
        end

        def upload_aki
          puts "Uploading AKI..."
          aki   = "#{extract_path}/cirros-0.3.0-x86_64-vmlinuz"
          @aki  = @service.images.create(
            :name             => "#{image_name}-aki",
            :size             => File.size(aki),
            :disk_format      => 'aki',
            :container_format => 'aki',
            :location         => aki
          )
        end

        def upload_ari
          puts "Uploading ARI..."
          ari   = "#{extract_path}/cirros-0.3.0-x86_64-initrd"
          @ari  = @service.images.create(
            :name             => "#{image_name}-ari",
            :size             => File.size(ari),
            :disk_format      => 'ari',
            :container_format => 'ari',
            :location         => ari
          )
        end

        def upload_ami
          puts "Uploading AMI..."
          ami = "#{extract_path}/cirros-0.3.0-x86_64-blank.img"
          @service.images.create(
            :name             => image_name,
            :size             => File.size(ami),
            :disk_format      => 'ami',
            :container_format => 'ami',
            :location         => ami,
            :properties       => {
              'kernel_id'  => @aki.id,
              'ramdisk_id' => @ari.id
            }
          )
        end

        def image_path
          @image_path ||= "/tmp/cirros-image-#{SecureRandom.hex}.tar.gz"
        end

        def extract_path
          @extract_path ||= "/tmp/cirros-#{SecureRandom.hex}-dir"
        end

        def image_name
          @image_name ||= "cirros-0.3.0-amd64"
        end
      end
    end
  end
end
