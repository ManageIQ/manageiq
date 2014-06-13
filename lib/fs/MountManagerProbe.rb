$:.push("#{File.dirname(__FILE__)}/modules")

module MountManagerProbe
	MODDIR = File.expand_path(File.join(File.dirname(__FILE__), "modules"))

  PROBE_FILES = Dir.glob(File.join(MODDIR, "*Probe.rb*"))
  PROBE_FILES.each do |p|
    p.slice!(0..MODDIR.length)
    p.chomp!(".enc")
    p.chomp!(".rb")
  end
  # Reorder known probes for optimization
  PROBE_FILES.unshift("WinMountProbe") if PROBE_FILES.delete("WinMountProbe")

	def self.getRootMod(dobj, probes = nil)
    probes = PROBE_FILES if probes.nil?
    probes = [probes] unless probes.kind_of?(Array)

		probes.each do |pmod|
      $log.debug "MIQ(MountManagerProbe-getRootMod) Mount Manager probe attempting [#{pmod}]"
			require pmod
      if Object.const_get(pmod).probe(dobj)
        mod = pmod.chomp("Probe")
        $log.info "MIQ(MountManagerProbe-getRootMod) Mount Manager probe detected [#{mod}]"
        require mod
        return Object.const_get(mod)
      end
		end
		return nil
	end
end
