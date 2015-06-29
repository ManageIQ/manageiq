$:.push("#{File.dirname(__FILE__)}/modules")

module FsProbe
	MODDIR = File.expand_path(File.join(File.dirname(__FILE__), "modules"))

  PROBE_FILES = Dir.glob(File.join(MODDIR, "*Probe.rb*"))
  PROBE_FILES.each do |p|
    p.slice!(0..MODDIR.length)
    p.chomp!(".enc")
    p.chomp!(".rb")
  end
  # Reorder known probes for optimization
  PROBE_FILES.unshift("Fat32Probe")    if PROBE_FILES.delete("Fat32Probe")
  PROBE_FILES.unshift("Reiser4Probe")  if PROBE_FILES.delete("Reiser4Probe")
  PROBE_FILES.unshift("ReiserFSProbe") if PROBE_FILES.delete("ReiserFSProbe")
  PROBE_FILES.unshift("Ext4Probe")     if PROBE_FILES.delete("Ext4Probe")
  PROBE_FILES.unshift("Ext3Probe")     if PROBE_FILES.delete("Ext3Probe")
  PROBE_FILES.unshift("NTFSProbe")     if PROBE_FILES.delete("NTFSProbe")

	def self.getFsMod(dobj, probes = nil)
    probes = PROBE_FILES if probes.nil?
    probes = [probes] unless probes.kind_of?(Array)

    fname = dobj.dInfo.fileName || "" rescue ""
    fname = dobj.dInfo.lvObj.lvName || "" if fname.empty? rescue ""
    partNum = dobj.partNum

		probes.each do |pmod|
      $log.debug "MIQ(FsProbe-getFsMod) FS probe attempting [#{pmod}] for [#{fname}] [partition: #{partNum}]"
			require pmod
      if Object.const_get(pmod).probe(dobj)
        mod = pmod.chomp("Probe")
        $log.info "MIQ(FsProbe-getFsMod) FS probe detected [#{mod}] for [#{fname}] [partition: #{partNum}]"
        require mod
        return Object.const_get(mod)
      end
		end
		return nil
	end
end
