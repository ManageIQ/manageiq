module ImageMethods
  def fog_image
    @fog_image ||= connect("Image")
  end

  def find_or_create_image(collection, attributes)
    obj = find(collection, attributes)
    obj || begin
      @image_name = attributes[:name]
      import_image
    end
  end

  def find_or_create_image_from_server(collection, server, attributes)
    obj = find(collection, attributes)
    obj || create_image_from_server(server, attributes)
  end

  private

  def create_image_from_server(server, attributes)
    attributes = attributes.values_at(:name)
    create(server, attributes, :create_image)
  end

  def import_image
    # Based on https://github.com/fog/fog/blob/master/lib/fog/openstack/examples/image/upload-test-image.rb
    # Download CirrOS 0.3.0 image from launchpad (~6.5MB) to /tmp and upload it to Glance.
    download_image
    extract_image

    upload_aki
    upload_ari
    upload_ami
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
    @aki  = fog_image.images.create(
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
    @ari  = fog_image.images.create(
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
    fog_image.images.create(
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
    "/tmp/cirros-image-#{SecureRandom.hex}.tar.gz"
  end

  def extract_path
    "/tmp/cirros-#{SecureRandom.hex}-dir"
  end

  def image_name
    @image_name ||= "cirros-0.3.0-amd64"
  end
end
