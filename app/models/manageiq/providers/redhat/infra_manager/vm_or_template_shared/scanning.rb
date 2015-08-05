module ManageIQ::Providers::Redhat::InfraManager::VmOrTemplateShared::Scanning
  def perform_metadata_scan(ost)
    require 'MiqVm/MiqRhevmVm'

    log_pref = "MIQ(#{self.class.name}##{__method__})"
    vm_name  = File.uri_to_local_path(ost.args[0])
    $log.debug "#{log_pref} VM = #{vm_name}"

    args1 = ost.args[1]
    args1['ems']['connect'] = true if args1[:mount].blank?

    begin
      @vm_cfg_file = vm_name
      connect_to_ems(ost)
      miq_vm = MiqRhevmVm.new(@vm_cfg_file, ost)
      scan_via_miq_vm(miq_vm, ost)
    rescue => err
      $log.error "#{log_pref}: #{err}"
      $log.debug err.backtrace.join("\n")
      raise
    ensure
      miq_vm.unmount if miq_vm
      unmount_storage(@mount)
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  private

  # Moved from MIQExtract.rb
  def connect_to_ems(ost)
    log_header = "MIQ(#{self.class.name}.#{__method__})"
    @mount = storage_mounts(ost.taskid)
    unless @mount.blank?
      ost.nfs_mount = true
      $rhevm_mount_root = @mount[:base_dir] # XXX $ ?
      $log.info "#{log_header} Mounting storage for VM at <#{$rhevm_mount_root}>"
      mount_storage(@mount)
      @vm_cfg_file = File.join($rhevm_mount_root, @vm_cfg_file)
      return
    end

    # Check if we've been told explicitly not to connect to the ems
    # TODO: See vm_scan.rb: config_ems_list() - is this always false for RedHat?
    if ost.scanData.fetch_path("ems", 'connect') == false
      $log.debug "#{log_header}: returning, ems/connect == false"
      return
    end

    # Make sure we were given a ems/host to connect to
    ems_connect_type = ost.scanData.fetch_path('ems', 'connect_to') || 'host'
    miqVimHost = ost.scanData.fetch_path("ems", ems_connect_type)
    if miqVimHost
      st = Time.now
      use_broker = false
      miqVimHost[:address] = miqVimHost[:ipaddress] if miqVimHost[:address].nil?
      ems_display_text = "#{ems_connect_type}(#{use_broker ? 'via broker' : 'directly'}):#{miqVimHost[:address]}"
      $log.info "#{log_header}: Connecting to [#{ems_display_text}] for VM:[#{@vm_cfg_file}]"
      miqVimHost[:password_decrypt] = MiqPassword.decrypt(miqVimHost[:password])

      begin
        #
        # The functionality that was formerly required through 'rhevm_inventory'
        # has been moved to the 'overt' gem. If that functionality is ever moved
        # out of the 'overt' gem, then this require will need to be changed accordingly.
        #
        $log.debug "#{log_header}: before require 'overt'"
        require 'ovirt'
        ems_opt = {
          :server     => miqVimHost[:address],
          :username   => miqVimHost[:username],
          :password   => miqVimHost[:password_decrypt],
          :verify_ssl => false
        }
        ems_opt[:port] = miqVimHost[:port] unless miqVimHost[:port].blank?

        rhevm = Ovirt::Inventory.new(ems_opt)
        rhevm.api
        ost.miqRhevm = rhevm
        $log.info "Connection to [#{ems_display_text}] completed for VM:[#{@vm_cfg_file}] in [#{Time.now - st}] seconds"
      rescue Timeout::Error => err
        msg = "#{log_header}: Connection to [#{ems_display_text}] timed out for VM:[#{@vm_cfg_file}] with error [#{err}] after [#{Time.now - st}] seconds"
        $log.error msg
        raise err, msg, err.backtrace
      rescue Exception => err
        msg = "#{log_header}: Connection to [#{ems_display_text}] failed for VM:[#{@vm_cfg_file}] with error [#{err}] after [#{Time.now - st}] seconds"
        $log.error msg
        raise err, msg, err.backtrace
      end
    end
  end

  # Moved from MIQExtract.rb
  def mount_storage(mount_hash)
    require 'util/mount/miq_nfs_session'
    log_header = "MIQ(MIQExtract.mount_storage)"
    $log.info "#{log_header} called"

    begin
      FileUtils.mkdir_p(mount_hash[:link_path]) unless File.directory?(mount_hash[:link_path])
      mount_hash[:mount_points].each do |mnt|
        $log.info "#{log_header} Creating mount point <#{mnt.inspect}>"
        MiqNfsSession.new(mnt).connect
      end
      $log.info "#{log_header} - mount:\n#{`mount`}"
      mount_hash[:symlinks].each do |link|
        $log.info "#{log_header} Creating symlink <#{link.inspect}>"
        File.symlink(link[:source], link[:target])
      end
    rescue
      $log.error "#{log_header} Unable to mount all items from <#{mount_hash[:base_dir]}>"
      unmount_storage(mount_hash)
      raise $!
    end
  end

  # Moved from MIQExtract.rb
  def unmount_storage(mount_hash)
    return # XXX
    log_header = "MIQ(MIQExtract.unmount_storage)"
    $log.debug "#{log_header}: mount_hash = #{mount_hash.class.name}"
    return if mount_hash.blank?
    begin
      $log.warn "#{log_header} Unmount all items from <#{mount_hash[:base_dir]}>"
      mount_hash[:mount_points].each { |mnt| MiqNfsSession.disconnect(mnt[:mount_point]) }
      FileUtils.rm_rf(mount_hash[:base_dir])
    rescue
      $log.warn "#{log_header} Failed to unmount all items from <#{mount_hash[:base_dir]}>.  Reason: <#{$!}>"
    end
  end

  # Helper method for VM scanning
  # Moved from providers/redhat/infra_manager.rb
  def storage_mounts(job_id = nil)
    return nil unless storage && storage.store_type == "NFS"

    datacenter = parent_datacenter
    raise "VM <#{name}> is not attached to a Data-center" if datacenter.blank?

    base_path = File.join('/mnt', 'vm', job_id)
    base_rhevm_path = File.join(base_path, 'rhev', 'data-center')
    mnt_path  = File.join(base_rhevm_path, 'mnt')
    link_path = File.join(base_rhevm_path, datacenter.uid_ems)

    # Find the storages we need to mount to access this VM
    hms = storage.hosts.first.storages.detect { |s| s.master? && s.store_type == "NFS" }
    storages = [storage, hms].uniq.compact

    result = {:mount_points => [], :symlinks => [], :base_dir => base_path, :link_path => link_path}
    storages.each do |s|
      uri = s.location.gsub('//', ':/').strip
      s_mnt_path = File.join(mnt_path, uri.gsub('/', '_'))
      result[:mount_points] << mount_parms = {:uri => "nfs://#{uri}", :mount_point => s_mnt_path}

      storage_guid = s.ems_ref.split('/').last
      link_name = File.join(link_path, storage_guid)
      link_mnt_path = File.join(mount_parms[:mount_point], storage_guid)

      # Determine what symlinks we need to make
      result[:symlinks] << {:source => link_mnt_path, :target => link_name}
      result[:symlinks] << {:source => link_mnt_path, :target => File.join(link_path, 'mastersd')} if s.master?
    end

    result
  end
end
