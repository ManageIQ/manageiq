require_relative 'data'

module Openstack
  module Services
    module Storage
      class Builder
        attr_reader :service

        def self.build_all(ems, project)
          new(ems, project).build_all
        end

        def initialize(ems, project)
          @service = ems.connect(:tenant_name => project.name, :service => "Storage")
          @data    = Data.new
          @project = project

          # Collected data
          @directories = []
          @files       = []
        end

        def build_all
          find_or_create_directories

          self
        end

        private

        def find_or_create_directories
          @data.directories.each do |directory_data|
            @directories << directory = (find(@service.directories, directory_data.slice(:key)) ||
              create_directory(@service.directories, directory_data))

            find_or_create_files(directory)
          end
        end

        def create_directory(collection, directory_data)
          puts "Creating #{directory_data} against #{collection.class.name}"
          directory = collection.new(directory_data)
          directory.save
          directory
        end

        def find_or_create_files(directory)
          return if @data.files(directory.key).blank?

          @data.files(directory.key).each do |file|
            @files << (find(directory.files, file.slice(:key)) ||
              create_file(directory.files, file))
          end
        end

        def create_file(collection, file_data)
          puts "Creating #{file_data} against #{collection.class.name}"
          body = file_data.delete(:__body)

          file = collection.new(file_data)
          file.body = body
          file.save
          file
        end

        def wait_for_volume(volume)
          name = volume.respond_to?(:name) ? volume.name : volume.display_name

          print "Waiting for volume #{name} to get in a desired state..."

          loop do
            case volume.reload.status
            when "available", "in-use"
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
