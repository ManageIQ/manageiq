class ManageIQ::Providers::Redhat::InfraManager::DiskAttachmentBuilder
  def initialize(options = {})
    @size_in_mb = options[:size_in_mb]
    @storage = options[:storage]
    @name = options[:name]
    @thin_provisioned = BooleanParameter.new(options[:thin_provisioned])
    @bootable = BooleanParameter.new(options[:bootable])
    @active = options[:active]
    @interface = options[:interface]
  end

  def disk_attachment
    thin_provisioned = @thin_provisioned.true?
    {
      :bootable  => @bootable.true?,
      :interface => @interface || "VIRTIO",
      :active    => @active,
      :disk      => {
        :name             => @name,
        :provisioned_size => @size_in_mb.to_i.megabytes,
        :sparse           => thin_provisioned,
        :format           => self.class.disk_format_for(@storage, thin_provisioned),
        :storage_domains  => [:id => ManageIQ::Providers::Redhat::InfraManager.extract_ems_ref_id(@storage.ems_ref)]
      }
    }
  end

  FILE_STORAGE_TYPE = %w(NFS GLUSTERFS VMFS).to_set.freeze
  BLOCK_STORAGE_TYPE = %w(FCP ISCSI).to_set.freeze

  def self.disk_format_for(storage, thin_provisioned)
    if FILE_STORAGE_TYPE.include?(storage.store_type)
      "raw"
    elsif BLOCK_STORAGE_TYPE.include?(storage.store_type)
      thin_provisioned ? "cow" : "raw"
    else
      "raw"
    end
  end

  class BooleanParameter
    def initialize(param)
      @value = param.to_s == "true"
    end

    def true?
      @value
    end
  end
end
