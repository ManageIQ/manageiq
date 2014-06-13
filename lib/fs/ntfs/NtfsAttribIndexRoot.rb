require 'NtUtil'

$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'
require 'miq-unicode'

require 'NtfsIndexNodeHeader'
require 'NtfsDirectoryIndexNode'
require 'NtfsIndexRecordHeader'

module NTFS
		
  # 
  # INDEX_ROOT - Attribute: Index root (0x90).
  # 
  # NOTE: Always resident.
  # 
  # This is followed by a sequence of index entries (INDEX_ENTRY structures)
  # as described by the index header.
  # 
  # When a directory is small enough to fit inside the index root then this
  # is the only attribute describing the directory. When the directory is too
  # large to fit in the index root, on the other hand, two additional attributes
  # are present: an index allocation attribute, containing sub-nodes of the B+
  # directory tree (see below), and a bitmap attribute, describing which virtual
  # cluster numbers (vcns) in the index allocation attribute are in use by an
  # index block.
  # 
  # NOTE: The root directory (FILE_root) contains an entry for itself. Other
  # directories do not contain entries for themselves, though.
  # 

	ATTRIB_INDEX_ROOT = BinaryStruct.new([
		'L',  'type',                     # Type of the indexed attribute. Is FILE_NAME for directories, zero
    					                        # for view indexes. No other values allowed.
		'L',  'collation_rule',           # Collation rule used to sort the index entries. If type is $FILE_NAME, 
		                                  # this must be COLLATION_FILE_NAME
		'L',  'index_block_size',         # Size of index block in bytes (in the index allocation attribute)
		'C',  'clusters_per_index_block', # Size of index block in clusters (in the index allocation attribute), 
		                                  # when an index block is >= than a cluster, otherwise sectors per index block
		'a3', nil,                        # Reserved/align to 8-byte boundary
	])
	# Here follows a node header.
	SIZEOF_ATTRIB_INDEX_ROOT = ATTRIB_INDEX_ROOT.size

	class IndexRoot

    DEBUG_TRACE_FIND = false && $log

		CT_BINARY		= 0x00000000	# Binary compare, MSB is first (does that mean big endian?)
		CT_FILENAME	= 0x00000001	# UNICODE strings.
		CT_UNICODE	= 0x00000002	# UNICODE, upper case first.
		CT_ULONG		= 0x00000010	# Standard ULONG, 32-bits little endian.
		CT_SID			= 0x00000011	# Security identifier.
		CT_SECHASH	= 0x00000012	# First security hash, then security identifier.
		CT_ULONGS		= 0x00000013	# Set of ULONGS? (doc is unclear - indicates GUID).

	  def self.create_from_header(header, buf, bs)
		  return IndexRoot.new(buf, bs) if header.containsFileNameIndexes?
      $log.debug("Skipping #{header.typeName} for name <#{header.name}>") if $log
      return nil
	  end

		attr_reader :type, :nodeHeader, :index, :indexAlloc

		def initialize(buf, boot_sector)
			log_prefix = "MIQ(NTFS::IndexRoot.initialize)"

			raise "#{log_prefix} Nil buffer"        if buf.nil?
			raise "#{log_prefix} Nil boot sector"   if boot_sector.nil?

			buf                = buf.read(buf.length) if buf.kind_of?(DataRun)
			@air               = ATTRIB_INDEX_ROOT.decode(buf)
			buf                = buf[SIZEOF_ATTRIB_INDEX_ROOT..-1]

			# Get accessor data.
			@type              = @air['type']
			@collation_rule    = @air['collation_rule']
			@byteSize          = @air['index_block_size']
			@clusterSize       = @air['size_of_index_clus']

			@boot_sector       = boot_sector

			# Get node header & index.
			@foundEntries      = {}
			@indexNodeHeader   = IndexNodeHeader.new(buf)
			@indexEntries      = cleanAllocEntries(DirectoryIndexNode.nodeFactory(buf[@indexNodeHeader.startEntries..-1]))
			@indexAlloc        = {}
		end

		def to_s
			@type.to_s
		end

    def allocations=(indexAllocations)
      @indexAllocRuns = []
      if @indexNodeHeader.hasChildren? && indexAllocations
        indexAllocations.each { |alloc| @indexAllocRuns << [alloc.header, alloc.data_run] }
      end
      @indexAllocRuns
    end

    def bitmap=(bmp)
      if @indexNodeHeader.hasChildren?
        @bitmap = bmp.data.unpack("b#{bmp.length * 8}") unless bmp.nil?
      end

      @bitmap
    end

		# Find a name in this index.
		def find(name)
      log_prefix = "MIQ(NTFS::IndexRoot.find)"

      name = name.downcase
      $log.debug "#{log_prefix} Searching for [#{name}]" if DEBUG_TRACE_FIND
      if @foundEntries.has_key?(name)
        $log.debug "#{log_prefix} Found [#{name}] (cached)" if DEBUG_TRACE_FIND
        return @foundEntries[name]
      end

      found = findInEntries(name, @indexEntries)
      if found.nil?
        # Fallback to full directory search if not found
        $log.debug "#{log_prefix} [#{name}] not found.  Performing full directory scan." if $log
        found = findBackup(name)
        $log.send(found.nil? ? :debug : :warn, "#{log_prefix} [#{name}] #{found.nil? ? "not " : ""}found in full directory scan.")  if $log
      end
      return found
    end

		# Return all names in this index as a sorted string array.
		def globNames
      @globNames = globEntries.collect { |e| e.namespace == NTFS::FileName::NS_DOS ? nil : e.name.downcase }.compact if @globNames.nil?
      return @globNames
		end

    def findInEntries(name, entries)
      log_prefix = "MIQ(NTFS::IndexRoot.findInEntries)"

      if @foundEntries.has_key?(name)
        $log.debug "#{log_prefix} Found [#{name}] in #{entries.collect {|e| e.isLast? ? "**last**" : e.name.downcase}.inspect}" if DEBUG_TRACE_FIND
        return @foundEntries[name]
      end

      $log.debug "#{log_prefix} Searching for [#{name}] in #{entries.collect {|e| e.isLast? ? "**last**" : e.name.downcase}.inspect}" if DEBUG_TRACE_FIND
      # TODO: Uses linear search within an index entry; switch to more performant search eventually
      entries.each do |e|
        $log.debug "#{log_prefix} before [#{e.isLast? ? "**last**" : e.name.downcase}]" if DEBUG_TRACE_FIND
        if e.isLast? || name < e.name.downcase
          $log.debug "#{log_prefix} #{e.hasChild? ? "Sub-search in child vcn [#{e.child}]" : "No sub-search"}" if DEBUG_TRACE_FIND
          return e.hasChild? ? findInEntries(name, getIndexAllocEntries(e.child)) : nil
        end
      end
      $log.debug "#{log_prefix} Did not find [#{name}]" if DEBUG_TRACE_FIND
      return nil
    end

    def findBackup(name)
      return globEntriesByName[name]
    end

    def getIndexAllocEntries(vcn)
      unless @indexAlloc.has_key?(vcn)
        log_prefix = "MIQ(NTFS::IndexRoot.getIndexAllocEntries)"

        begin
          raise "not allocated"    if @bitmap[vcn, 1] == "0"
          header, run = @indexAllocRuns.detect { |h, r| vcn >= h.specific['first_vcn'] && vcn <= h.specific['last_vcn'] }
          raise "header not found" if header.nil?
          raise "run not found"    if run.nil?

          run.seekToVcn(vcn - header.specific['first_vcn'])
          buf = run.read(@byteSize)

          raise "buffer not found" if buf.nil?
          raise "buffer signature is expected to be INDX, but is [#{buf[0, 4].inspect}]" if buf[0, 4] != "INDX"
          irh = IndexRecordHeader.new(buf, @boot_sector.bytesPerSector)
          buf = irh.data[IndexRecordHeader.size..-1]
          inh = IndexNodeHeader.new(buf)
          @indexAlloc[vcn] = cleanAllocEntries(DirectoryIndexNode.nodeFactory(buf[inh.startEntries..-1]))
        rescue => err
          $log.warn "#{log_prefix} Unable to read data from index allocation at vcn [#{vcn}] because <#{err.message}>\n#{dump}" if $log
          @indexAlloc[vcn] = []
        end
      end

      @indexAlloc[vcn]
    end

    def cleanAllocEntries(entries)
      cleanEntries = []
      entries.each do |e|
        if e.isLast? || !(e.contentLen == 0 || (e.refMft[1] < 12 && e.name[0,1] == "$"))
          cleanEntries << e
          # Since we are already looping through all entries to clean
          #   them we can store them in a lookup for optimization
          @foundEntries[e.name.downcase] = e unless e.isLast?
        end
      end
      return cleanEntries
    end

    def globEntries
      return @globEntries unless @globEntries.nil?

      # Since we are reading all entries, retrieve all of the data in one call
      @indexAllocRuns.each do |h, r|
        r.rewind
        r.read(r.length)
      end

      return @globEntries = globAllEntries(@indexEntries)
    end

    def globEntriesByName
      log_prefix = "MIQ(NTFS::IndexRoot.globEntriesByName)"

      if @globbedEntriesByName
        $log.debug "#{log_prefix} Using cached globEntries." if DEBUG_TRACE_FIND
        return @foundEntries
      end

      $log.debug "#{log_prefix} Initializing globEntries:" if DEBUG_TRACE_FIND
      globEntries.each do |e|
        $log.debug "#{log_prefix} #{e.isLast? ? "**last**" : e.name.downcase}" if DEBUG_TRACE_FIND
        @foundEntries[e.name.downcase] = e
      end
      @globbedEntriesByName = true
      return @foundEntries
    end

    def globAllEntries(entries)
      ret = []
      entries.each do |e|
        ret += globAllEntries(getIndexAllocEntries(e.child)) if e.hasChild?
        ret << e unless e.isLast?
      end
      return ret
    end

		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Type                 : 0x#{'%08x' % @type}\n"
			out << "  Collation Rule       : #{@collation_rule}\n"
			out << "  Index size (bytes)   : #{@byteSize}\n"
			out << "  Index size (clusters): #{@clusterSize}\n"
			@indexEntries.each { |din| out << din.dump }
			out << "---\n"
			return out
		end

	end

end # module NTFS
