$:.push("#{File.dirname(__FILE__)}/modules")

module DiskProbe
	MODDIR = File.expand_path(File.join(File.dirname(__FILE__), "modules"))

  PROBE_FILES = Dir.glob(File.join(MODDIR, "*Probe.rb*"))
  PROBE_FILES.each do |p|
    p.slice!(0..MODDIR.length)
    p.chomp!(".enc")
    p.chomp!(".rb")
  end
  # Reorder known probes for optimization
  %w{VixDiskProbe VMWareDiskProbe RhevmDiskProbe}.reverse.each {|probe| PROBE_FILES.unshift(probe) if PROBE_FILES.delete(probe)}
  PROBE_FILES.push("LocalDevProbe") if PROBE_FILES.delete("LocalDevProbe")

	def self.getDiskMod(dobj, probes = nil)
    probes = PROBE_FILES if probes.nil?
    probes = [probes] unless probes.kind_of?(Array)

    fname = dobj.fileName rescue ""
    
    mod = nil
		probes.each do |pmod|
      $log.debug "MIQ(DiskProbe-getDiskMod) Disk probe attempting [#{pmod}] for [#{fname}]"
			require pmod
			begin
        mod = Object.const_get(pmod).probe(dobj)
        if mod
          $log.info "MIQ(DiskProbe-getDiskMod) Disk probe detected [#{pmod.chomp("Probe")}-#{mod}] for [#{fname}]"
          require mod
          return Object.const_get(mod)
        end
			rescue => err
        $log.warn "MIQ(DiskProbe-getDiskMod) [#{pmod.chomp("Probe")}-#{mod}] for [#{fname}]: #{err.to_s}"
			end
		end
		return nil
	end

  def self.getDiskModForDisk(disk, probes = nil)
    probes ||= PROBE_FILES
    probes = [probes] unless probes.kind_of?(Array)

    fname = disk.dInfo.fileName rescue ""
    
    mod = nil
    probes.each do |pmodstr|
      $log.debug "MIQ(DiskProbe-getDiskModForDisk) Disk probe attempting [#{pmodstr}] for [#{fname}]"
      require pmodstr
      begin
        pmod = Object.const_get(pmodstr)
        unless pmod.respond_to?(:stackable?) && pmod.stackable?
          $log.debug "MIQ(DiskProbe-getDiskModForDisk) Disk probe skipping [#{pmodstr}], not stackable"
          next
        end
        dmodstr = pmod.probeByDisk(disk)
        if dmodstr
          $log.info "MIQ(DiskProbe-getDiskModForDisk) Disk probe detected [#{pmodstr.chomp("Probe")}-#{dmodstr}] for [#{fname}]"
          require dmodstr
          return Object.const_get(dmodstr)
        end
      rescue => err
        $log.warn "MIQ(DiskProbe-getDiskModForDisk) [#{pmodstr.chomp("Probe")}-#{dmodstr}] for [#{fname}]: #{err.to_s}"
      end
    end
    $log.info "MIQ(DiskProbe-getDiskModForDisk) No module detected for [#{fname}]"
    return nil
  end
end
