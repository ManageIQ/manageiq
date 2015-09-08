class AddContainerImageDigest < ActiveRecord::Migration
  # https://github.com/docker/distribution/blob/v2.1.1/digest/digester.go#L15-L17
  SUPPORTED_DIGESTS = 'sha256', 'sha384', 'sha512'

  class ContainerImage < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    add_column :container_images, :digest, :string
    SUPPORTED_DIGESTS.each do |digest|
      say_with_time("Update container images with digest #{digest}") do
        ContainerImage.where("tag LIKE '#{digest}:%'").update_all('digest = tag, tag = null')
      end
    end
  end

  def down
    say_with_time("Update container images tags from digests") do
      ContainerImage.where("digest is not null").update_all('tag = digest')
    end
    remove_column :container_images, :digest
  end
end
