class HandleStorageDuplication
  attr_reader :ems, :dry_run, :verbose
  def initialize(opts)
    @ems = opts[:ext_management_system]
    @dry_run = opts[:dry_run]
    @verbose = opts[:verbose]
  end

  def effected_storages
    @effected_storages ||= @ems ? @ems.storages.where.not(:store_type => ["NFS", "GLANCE"]) : Storage.where.not(:store_type => ["NFS", "GLANCE"])
  end

  def handle_duplicates
    effected_storages.each do |storage|
      old_st_location = old_storage_location(storage)
      next if old_st_location == storage.location

      old_storage = Storage.where(location: old_st_location).first
      merge_old_storage(storage, old_storage) if old_storage
    end
  end

  def old_storage_location(storage)
    ext_management_systems = storage.ext_management_system ? [storage.ext_management_system] : ManageIQ::Providers::Redhat::InfraManager.all
    storagedomain = nil
    ext_management_systems.detect do |ems|
      storage_id = storage.ems_ref.split("/").last
      storagedomain = ems.with_provider_connection do |conn|
        conn.system_service.storage_domains_service.storage_domain_service(storage_id).get
      end
    end
    return nil unless storagedomain
    logical_units = storagedomain.dig(:storage, :volume_group, :logical_units)
    logical_unit =  logical_units&.first
    logical_unit&.id
  end

  def merge_old_storage(storage, old_storage)
    will_or_would = dry_run ? "Would have been deleted" : "Will be deleted"
    if verbose
      puts "The storage #{old_storage.name}, with id: #{old_storage.id} and location #{old_storage.location}"\
        "#{will_or_would} and its tags moved to: #{storage.name}, with id: #{storage.id} and location #{storage.location}"
    end
    return if dry_run

    transfer_tags(storage, old_storage)
    old_storage.reload.destroy
  end

  def transfer_tags(storage, old_storage)
    old_taggings = old_storage.taggings
    old_taggings.each do |old_tagging|
      old_tagging.update_column(:taggable_id, storage.id)
    end
  end
end
