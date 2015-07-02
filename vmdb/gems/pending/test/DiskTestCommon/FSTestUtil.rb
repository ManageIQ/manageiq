module FSTestUtil
	def FSTestUtil.lookSystemDir(fs)
		dir = "/windows";	return dir if fs.fileExists?(dir)
		dir = "/winnt";		return dir if fs.fileExists?(dir)
		return nil
	end
	
	def FSTestUtil.getSystemDir(fs)
		# Determine path to system root.
		# NOTE: default boot is assumed, and this won't work for Vista.
		boot = "/boot.ini"
		f = fs.fileOpen(boot, "r"); buf = f.read(); f.close(); buf = buf.split("\r\n")
		systemRoot = ""; buf.each {|line| systemRoot = line if line =~ /default/}
		systemRoot = systemRoot.split("\\")[1..-1].join("/")
		# NOTE: Assuming vol C is system.
		systemRoot = "/" + systemRoot
		return systemRoot
	end
end
