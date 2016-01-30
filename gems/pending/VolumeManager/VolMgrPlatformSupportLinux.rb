require 'util/miq-password'
require 'VMwareWebService/MiqVim'

module VolMgrPlatformSupportLinux
  def init
    $log.debug "VolMgrPlatformSupportLinux.init: #{@cfgFile}"
    @ems = nil
    @snMor = nil
    @vi = nil
    @vimVm = nil

    unless @ost.force
      $log.info "VolMgrPlatformSupportLinux.init: force flag = false"
      return
    end

    if @ost.miqVimVm
      $log.debug "VolMgrPlatformSupportLinux.init: Have miqVimVm"
      @vimVm = @ost.miqVimVm
      return
    end

    $log.debug "VolMgrPlatformSupportLinux.init: miqVimVm not set - should be a non VMware VM"
  end

  def preMount
    $log.debug "VolMgrPlatformSupportLinux.preMount Enter: force = #{@ost.force}"
    return unless @ost.force

    if @snMor
      $log.error "VolMgrPlatformSupportLinux.preMount - #{@cfgFile} is already mounted"
      return
    end

    unless @vimVm
      $log.warn "VolMgrPlatformSupportLinux.preMount: cannot snapshot VM not registered to this host: #{@cfgFile}"
      return
    end

    desc = @ost.snapshotDescription ? @ost.snapshotDescription : "EVM Snapshot"
    st = Time.now
    @snMor = @vimVm.createEvmSnapshot(desc, "false", true, @ost.snapshot_create_free_space)
    $log.info "VolMgrPlatformSupportLinux.preMount: VM snapshot created in [#{Time.now - st}] seconds"
    $log.debug "VolMgrPlatformSupportLinux.preMount: snMor = \"#{@snMor}\""
  end

  def postMount
    $log.debug "VolMgrPlatformSupportLinux.postMount Enter: force = #{@ost.force}, @vimVm.nil? = #{@vimVm.nil?}"
    return unless @ost.force
    return unless @vimVm

    if @ost.force
      if !@snMor
        $log.warn "VolMgrPlatformSupportLinux.postMount: VM not snapped: #{@cfgFile}"
      else
        $log.debug "VolMgrPlatformSupportLinux.postMount: removing snapshot snMor = \"#{@snMor}\""
        begin
          @vimVm.removeSnapshot(@snMor, "false", true, @ost.snapshot_remove_free_space)
        rescue => err
          $log.warn "VolMgrPlatformSupportLinux.postMount: failed to remove snapshot for VM: #{@cfgFile}"
          $log.warn "VolMgrPlatformSupportLinux.postMount: #{err}"
        end
      end
    end

    #
    # If we opened the vimVm (it wasn't passed into us)
    # then release it.
    #
    @vimVm.release unless @ost.miqVimVm
    @vimVm = nil

    @vi.disconnect if @vi
    @vi = nil
    @snMor = nil
  end
end # module VolMgrPlatformSupportLinux
