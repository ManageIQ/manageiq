$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../VMwareWebService")

require 'miq-password'
require 'MiqVim'

module VolMgrPlatformSupportLinux
        
    def init
        $log.debug "Initializing VolMgrPlatformSupportLinux: #{@cfgFile}" if $log.debug?
        @ems = nil
        @snMor = nil
        @vi = nil
        @vimVm = nil
        
        if !$miqHostCfg
            $log.warn "VolMgrPlatformSupportLinux: $miqHostCfg not set"
            return
        end
        
        $log.debug "VolMgrPlatformSupportLinux: $miqHostCfg.forceFleeceDefault = #{$miqHostCfg.forceFleeceDefault}" if $log.debug?
        @ost.force = $miqHostCfg.forceFleeceDefault if @ost.force.nil?
        
        if !@ost.force
            $log.info "Initializing VolMgrPlatformSupportLinux: force flag = false" if $log
            return  # Remove this if setDiskFlags is reactivated
        end
        
        if @ost.miqVimVm
            @vimVm = @ost.miqVimVm
            return
        end
        
        if !$miqHostCfg.emsLocal
            $log.warn "VolMgrPlatformSupportLinux: emslocal not set"
            return
        end
        if File.extname(@cfgFile) != ".vmx"
            $log.warn "VolMgrPlatformSupportLinux: @cfgFile is not a vmx file"
            return
        end
        
        $log.debug "VolMgrPlatformSupportLinux::init: emsLocal = #{$miqHostCfg.emsLocal}" if $log.debug?
        @ems = $miqHostCfg.ems[$miqHostCfg.emsLocal]
        
        @vi = MiqVim.new(@ems['host'], @ems['user'], MiqPassword.decrypt(@ems['password']))
        begin
            @vimVm = @vi.getVimVm(@cfgFile)
        rescue => err
            $log.debug "VolMgrPlatformSupportLinux::init: could not get MiqVimVm object for: #{@cfgFile}" if $log.debug?
            @vimVm = nil
        end
    end
    
    #
    # No longer used.
    #
    def setDiskFlags(dInfo)
        if !@vimVm
            $log.debug "VolMgrPlatformSupportLinux::setDiskFlags: vimVm not set, setting baseOnly = false" if $log.debug?
            return
        end
        if @ost.force
            $log.debug "VolMgrPlatformSupportLinux::setDiskFlags: force flag = true, setting baseOnly = false" if $log.debug?
            return
        end
        if !(si = @vimVm.snapshotInfo)
            $log.debug "VolMgrPlatformSupportLinux::setDiskFlags: VM has no snapshot information, setting baseOnly = false" if $log.debug?
            return
        end
        
        ssHash = si['ssMorHash']
        sn = ssHash[si['currentSnapshot'].to_s]['name']
        $log.debug "VolMgrPlatformSupportLinux::setDiskFlags: current snapshot name = #{sn}" if $log.debug?
        
        if sn == "EvmSnapshot"
            $log.debug "VolMgrPlatformSupportLinux::setDiskFlags: setting baseOnly = true" if $log.debug?
            dInfo.baseOnly = true
        end
    end
    
    def preMount
		$log.debug "VolMgrPlatformSupportLinux.preMount called" if $log.debug?
        return unless @ost.force
        
        if @snMor
            $log.error "VolMgrPlatformSupportLinux::preMount - #{@cfgFile} is already mounted"
            return
        end
        
        if !@vimVm
            $log.warn "VolMgrPlatformSupportLinux::preMount: cannot snapshot VM not registered to this host: #{@cfgFile}"
            return
        end
        
        desc = @ost.snapshotDescription ? @ost.snapshotDescription : "EVM Snapshot"
        st = Time.now
        @snMor = @vimVm.createEvmSnapshot(desc, "false", true, @ost.snapshot_create_free_space)
        $log.info "VM snapshot created in [#{Time.now-st}] seconds"
        $log.debug "VolMgrPlatformSupportLinux::preMount: snMor = \"#{@snMor}\"" if $log.debug?
    end
    
    def postMount
		$log.debug "VolMgrPlatformSupportLinux.postMount called" if $log.debug?
        return unless @ost.force
        return unless @vimVm
        
        if @ost.force
            if !@snMor
                $log.warn "VolMgrPlatformSupportLinux::postMount: VM not snapped: #{@cfgFile}"
            else
                $log.debug "VolMgrPlatformSupportLinux::postMount: removing snapshot snMor = \"#{@snMor}\"" if $log.debug?
                begin
                    @vimVm.removeSnapshot(@snMor, "false", true, @ost.snapshot_remove_free_space)
                rescue => err
                    $log.warn "VolMgrPlatformSupportLinux::postMount: failed to remove snapshot for VM: #{@cfgFile}"
                    $log.warn "VolMgrPlatformSupportLinux::postMount: #{err}"
                end
            end
        end

		#
		# If we opened the vimVm (it wasn't passed into us)
		# then release it.
		#
		@vimVm.release if !@ost.miqVimVm
		@vimVm = nil
        
        @vi.disconnect if @vi
        @vi = nil
        @snMor = nil
    end
    
end # module VolMgrPlatformSupportLinux
