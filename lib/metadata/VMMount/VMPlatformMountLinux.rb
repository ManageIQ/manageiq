$:.push("#{File.dirname(__FILE__)}/../../encryption")

require 'CryptString'

module VMPlatformMountLinux
    
    VCBNAME     = '/usr/sbin/vcbVmName'
    VCBSNAPSHOT = '/usr/sbin/vcbSnapshot'
    
    def init
        $log.debug "Initializing VMPlatformMountLinux: #{@dInfo.fileName}" if $log
        @ems = nil
        @snapSsId = nil
        
        if !@ost.force
            $log.debug "Initializing VMPlatformMountLinux: force flag = false" if $log
            return
        end
        
        return unless $miqHostCfg
        return unless $miqHostCfg.emsLocal
        return unless File.exists? VCBNAME
        return unless File.exists? VCBSNAPSHOT
        return unless File.extname(@dInfo.fileName) == ".vmdk"
        
        $log.debug "VMPlatformMountLinux::init: emsLocal = #{$miqHostCfg.emsLocal}" if $log
        @ems = $miqHostCfg.ems[$miqHostCfg.emsLocal]
        #
        # TODO: This won't always yield the VM name.
        #       While it works most of the time, we need to find a better way to do this.
        #
        @vmName  = File.basename(File.dirname(@dInfo.fileName))
        $log.debug "VMPlatformMountLinux::init: vmName = \""#{@vmName}\"" if $log
        #
        # TODO: passing the user name and password on the command line is BAD.
        #       Change this to use web-services.
        #
        @cs = CryptString.new
        cmd = "#{VCBNAME} -h #{@ems['host']} -u #{@ems['user']} -p #{@cs.decrypt(@ems['password'])} -s \"Name:#{@vmName}\" | grep \"moref:\""
        #
        # XXX Don't forget to remove this. We're logging the username and password, not good.
        #
        $log.debug "VMPlatformMountLinux::init: cmd = #{cmd}" if $log
        @vmMoref = `#{cmd}`.chomp
        $log.debug "VMPlatformMountLinux::init: vmMoref = \"#{@vmMoref}\"" if $log
    end
    
    def preMount
        return unless @ost.force
        return unless @ems
        cmd = "#{VCBSNAPSHOT} -h #{@ems['host']} -u #{@ems['user']} -p #{@cs.decrypt(@ems['password'])} -c \"#{@vmMoref}\" \"miq#{@vmName}snap\" | grep \"SsId:\""
        #
        # XXX Don't forget to remove this. We're logging the username and password, not good.
        #
        $log.debug "VMPlatformMountLinux::preMount: cmd = #{cmd}" if $log
        @snapSsId = `#{cmd}`.chomp
        $log.debug "VMPlatformMountLinux::preMount: snapSsId = \"#{@snapSsId}\"" if $log
        # The VMMount code selects the disk file before the snapshot is taken.
        # The file it selects should be the parent of the snapshot, so we should be OK.
        # This may not be the case fot other types of VMs.
        # @dInfo.baseOnly = true
    end
    
    def postMount
        return unless @ost.force
        #
        # TODO: Ensure the snapshot gets removed in the event something happens between the preMount and postMount.
        #
        return unless @snapSsId
        cmd = "#{VCBSNAPSHOT} -h #{@ems['host']} -u #{@ems['user']} -p #{@cs.decrypt(@ems['password'])} -d \"#{@vmMoref}\" \"#{@snapSsId}\""
        #
        # XXX Don't forget to remove this. We're logging the username and password, not good.
        #
        $log.debug "VMPlatformMountLinux::postMount: cmd = #{cmd}" if $log
        result = `#{cmd}`.chomp
        $log.debug "VMPlatformMountLinux::postMount: result = #{result}" if $log
    end
    
end # module VMPlatformMountLinux
