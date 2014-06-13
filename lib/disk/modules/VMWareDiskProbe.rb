module VMWareDiskProbe
    SPARSE_MAGIC = "KDMV"
    SPARSE_MOD   = "VMWareSparseDisk"
    COWD_MAGIC   = "COWD"
    COWD_MOD     = "VMWareCowdDisk"
		DESC_MOD     = "VMWareDescriptor"
    
	def VMWareDiskProbe.probe(ostruct)
	    return nil if !ostruct.fileName
		# If not .vmdk then not VMWare.
		# Allow .miq also.
		ext = File.extname(ostruct.fileName).downcase
		return nil if ext != ".vmdk" && ext != ".miq"
			
    size  = File.size(ostruct.fileName)
		f     = File.new(ostruct.fileName, "rb")
		magic = f.read(4)
		
		if magic == SPARSE_MAGIC
  		# get descriptor offset & size.
  		f.seek(24, IO::SEEK_CUR)
  		ofs = f.read(8).unpack("Q")[0]
  		siz = f.read(8).unpack("Q")[0]
		end
		
		binary = false
		if (magic != SPARSE_MAGIC) && (magic != COWD_MAGIC)
		  f.rewind
		  while true
		    data   = f.read(4096)
		    break if data.nil?
		    binary = binary_data?(data)
		    break if binary
	    end
	  end
		
		f.close
	    
		return COWD_MOD if magic == COWD_MAGIC
		
		if magic == SPARSE_MAGIC
			# If this ostruct already has a descriptor don't bother checking.
			# NOTE: If it does have a descriptor, we're coming from VMWareDescriptor.rb
			#       trying to open a disk - so don't regress infinitely.
			if ostruct.Descriptor == nil && ofs > 0
				getDescriptor(ofs, siz, ostruct) if ofs > 0
				return DESC_MOD
			end
			
			return SPARSE_MOD
		end

    return false if binary
		return DESC_MOD
	end
	
	def VMWareDiskProbe.getDescriptor(ofs, siz, ostruct)
		f = File.open(ostruct.fileName, "rb")
		f.seek(ofs * 512, IO::SEEK_SET)
		desc = f.read(siz * 512)
		f.close
		
		pos  = desc.index("\000")
		desc = desc[0...pos] unless pos.nil?
		ostruct.Descriptor = desc
	end
	
	def VMWareDiskProbe.binary_data?(str)
    return false if str.nil? || str.empty?
    return ( str.count( "^ -~", "^\r\n" ) / str.size > 0.3 || str.count( "\x00" ) > 0 ) unless str.empty?
  end
	
end # module VMWareDiskProbe
