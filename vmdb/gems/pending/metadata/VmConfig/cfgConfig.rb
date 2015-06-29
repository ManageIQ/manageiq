module CfgConfig
	def convert(filename)
		@convertText = ""
		$log.debug "Processing Windows Configuration file [#{filename}]"
		begin
			fh = File.open(filename)
			fh.each do |line|
				line.AsciiToUtf8!.strip!
				next if line.length == 0
				next if line =~ /^#.*$/
				next if !line.include?("=")
				k, v = line.split(/\s*=\s*/)
				self.send(k, v) if self.respond_to?(k)
			end		
			return @convertText
		ensure
			fh.close
		end
	end

	def name(value)
		vmName = value.gsub(/^"/, "").gsub(/"$/, "")
		add_item("displayName", vmName)
	end

	def memory(value)
		add_item("memsize", value)
	end
	
	def disk(value)
		eval(value).each do |d|
			diskProp = d.split(",")
			#scsi0:0.fileName = "Windows XP Professional x64 Edition.vmdk"
			add_item("scsi0:#{diskProp[1][-1..-1]}.fileName", File.basename(diskProp[0]))
		end
	end
	
	def add_item(var, value)
		@convertText += "#{var} = \"#{value}\"\n"
	end

  def vendor
    return "xen"
  end
end
