module NTFS
  class IndexAllocation
	
    def self.create_from_header(header, buf)
      return IndexAllocation.new(buf, header) if header.containsFileNameIndexes?
      $log.debug("Skipping #{header.typeName} for name <#{header.name}>") if $log
      return nil
    end
    
		attr_reader :data_run, :header

		def initialize(buf, header)
			raise "MIQ(NTFS::IndexAllocation.initialize) Buffer must be DataRun (passed #{buf.class.name})"          unless buf.kind_of?(DataRun)
		  raise "MIQ(NTFS::IndexAllocation.initialize) Header must be AttribHeader (passed #{header.class.name})"  unless header.kind_of?(NTFS::AttribHeader)
			
			@data_run = buf
			@header   = header
		end
    
  end
end
