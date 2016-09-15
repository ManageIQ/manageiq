class AddOpenshiftDataToContainerImage < ActiveRecord::Migration[5.0]
  def change
    add_column  :container_images, :architecture, :string
    add_column  :container_images, :author, :string
    add_column  :container_images, :command, :string, :array => true, :default => []
    add_column  :container_images, :entrypoint, :string, :array => true, :default => []
    add_column  :container_images, :docker_version, :string

    add_column  :container_images, :exposed_ports, :text
    add_column  :container_images, :environment_variables, :text

    add_column  :container_images, :size, :bigint

    add_column  :container_images, :created_on, :datetime
  end
end
