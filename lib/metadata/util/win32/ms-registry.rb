$:.push("#{File.dirname(__FILE__)}/../../../util")

require 'binary_struct'
require 'miq-unicode'
require 'enumerator'
require 'miq-xml'
require 'xml/xml_hash'

# Constants
DEBUG_PRINT = false
DEBUG_UNHANDLED_DATA = false
DEBUG_LOG_PERFORMANCE = false
DEBUG_FILE_READS = false

class MSRegHive
	attr_reader :fileLoadTime, :fileParseTime, :digitalProductKeys, :xmlNode

  # Size of the HBIN data (as well as initiale REGF) segments
  HBIN_SIZE = 0x1000
  # All data offsets in the registry DO NOT include the first block (REGF) which
  # is 0x1000 (same as HBIN) and the 4 byte 'hbin' signature
  REG_DATA_OFFSET = HBIN_SIZE + 0x4
	
	def initialize(path, hiveName, xmlNode, fs = "M:/", filter=nil)
		@RegPath = path.gsub(/^"/, "").gsub(/"$/, "")
		@hiveName = hiveName
		@xmlNode = xmlNode
		@fs = fs if fs.kind_of?(MiqFS)
		@expandEnv = {'%SystemDrive%'=>'C:', "%SystemRoot%"=>"\\Windows", "%ProgramFiles%"=>"\\Program Files"}
		@fileLoadTime, @fileParseTime = nil, nil
		@ccsIdx = 1			#CurrentControlSet default index
		@ccsName = "controlset%03d" % @ccsIdx
    @stats = {:cache_hits=>0, :file_reads=>0, :bytes_read=>0}
    @hbin = {}
		
		# Load up filters
    @filter_value = {}
    @filter = self.init_filters(filter)
        
		# Collect DigitalProductKeys as we find them for processing later
		@digitalProductKeys = []
	end

  def init_filters(filter)
    if filter.nil?
      @filter_value = nil if @filter_value.empty?
      return nil
    end
    filters = filter.collect {|f| self.create_filter_hash(f)}
    filters.compact!
    filters = nil if filters.empty?
    @filter_value = nil if @filter_value.empty?
    return filters
  end

  def create_filter_hash(filter)
    if filter.kind_of?(Hash)
      nh = filter
      nh[:key] = nh[:key].downcase.split("/")
      nh[:value].each {|v| @filter_value[v.downcase] = true} if nh[:value].kind_of?(Array)
    else
      nh = {:key => filter.downcase.split("/")}
    end
    nh[:key_path] = nh[:key].join('\\')
    nh[:depth] = nh[:depth].to_i
    return nh
  end

	def close
    # Force memory cleanup
		@hbin = nil
    GC.start
	end
	
	def parseHives()
		startTime = Time.now
		
		# Reads in the registry file and does some basic validation
		validateRegFile(File.join(@RegPath, @hiveName))
		
		@fileLoadTime = Time.now - startTime
		$log.info "Registry Load/Validate time = #{@fileLoadTime} sec" if DEBUG_LOG_PERFORMANCE

		startTime = Time.now
		pre_process
		
		# Start parsing the registry based on the data offset stored in the first record
    if @hiveName == 'ntuser.dat'
      parseRecord(@hiveHash[:data_offset], @xmlNode, nil, 0)
    else
      parseRecord(@hiveHash[:data_offset], @xmlNode, @hiveName, 0)
    end

		post_process
		
		@fileParseTime = Time.now - startTime
    parseStats = "Registry Parsing time = #{@fileParseTime} sec.  registry segments loaded:[#{@hbin.length}]" #if DEBUG_LOG_PERFORMANCE
    parseStats += "  Stats:[#{@stats.inspect}]" if DEBUG_FILE_READS
		$log.info parseStats
	end
	
	def pre_process
		# Determine what System/ControlSet00? to use when CurrentControlSet is 
		# referenced and update the filter list.
		determine_current_control_set if @hiveName == "system"

		# Load environment variables to be used to "expand string" (REG_EXPAND_SZ) resolution.
		#load_environment_variables
	end
	
	def post_process
    if @hiveName == "system"
      ccsNode = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SYSTEM\\#{@ccsName}", @xmlNode.root)
      if ccsNode
        $log.debug "Changing [#{@ccsName}] to CurrentControlSet"
        ccsNode.add_attribute(:keyname, 'CurrentControlSet')
      end
    end
	end

	def load_environment_variables
		$log.debug "Determining ControlControlSet index"
		save_filters = @filter
		@filter = [self.create_filter_hash("#{@ccsName}/Control/Session Manager/Environment".downcase.split("/"))]
		# Start parsing the registry based on the data offset stored in the first record
		ccsNode = MiqXml.newNode()
		parseRecord(@hiveHash[:data_offset], ccsNode, @hiveName, 0)
		@filter = save_filters
		
		#ccsNode.write(STDOUT,0)
		#@expandEnv = {"%SystemRoot%"=>"\\Windows", "%ProgramFiles%"=>"\\Program Files"}
	end
		
	def determine_current_control_set
		$log.debug "Determining ControlControlSet index"
		save_filters = @filter
		@filter = [self.create_filter_hash('select')]
		# Start parsing the registry based on the data offset stored in the first record
		#ccsNode = MiqXml.newNode(nil, REXML)
    ccsNode = XmlHash::Document.new("ccs")
		parseRecord(@hiveHash[:data_offset], ccsNode, @hiveName, 0)
		#idx = ccsNode.find_first("//value[@name\"Current\"]")
    @ccsIdx = 0
    ccsNode.elements[1].each_element_with_attribute(:name, "Current") {|e| @ccsIdx = e.text}
		@ccsIdx = 1 if @ccsIdx == 0
		@ccsName = "controlset%03d" % @ccsIdx
		@filter = save_filters
		# Search through the filter list and change any "CurrentControlSet" values to the proper idx
    if @filter
      @filter.each do |a1|
        if a1[:key][0] == "currentcontrolset"
          a1[:key][0] = @ccsName
          a1[:key_path] = a1[:key].join('\\')
        end
      end
    end
		$log.debug "ControlControlSet index will be set to [#{@ccsIdx}]"
	end
	
	def parseRecord(offset, xmlNode, fqName, level)
		type = read_buffer(offset, 1).downcase
		$log.debug sprintf("TYPE = [%s] at offset [0x%08x]", type, offset+REG_DATA_OFFSET) if DEBUG_PRINT
    begin
      self.send("parseRecord#{type}", offset, xmlNode, fqName, level)
    rescue => err
      $log.warn sprintf("Unhandled type encountered [%s] at file offset [0x%08X].  Msg:[#{err}]", type, offset+REG_DATA_OFFSET) if DEBUG_UNHANDLED_DATA
    end
	end
	
	def checkFilters(subKey, fqName, level)
		return true if @filter.nil?  # If there are no filters get out
		match = false
		#allNil = true
    alevel = level-1
		
		@filter.each do |f|
      #      $log.debug "Filer [#{f[level]}]"
      #      allNil = false unless f[level].nil?
      if f[:key][alevel].nil? && fqName.downcase.index(f[:key_path])
        match = true if f[:depth].to_i == 0

        filter_depth = f[:depth] - 1 + f[:key].length
        if filter_depth >= level
          #$log.fatal "REG FILTER 1 fqName:[#{fqName.downcase}] - f[path]:[#{f[:key].join('\\')}] - depth:[#{filter_depth}] -- level:[#{level}]"
          match = true
          break
        end
      end
      if match==false && !f[:key][alevel].nil? && f[:key][alevel] == subKey
        match = true
        break
      end
		end
		#    $log.debug "match [#{match}]  allNil [#{allNil}]"
		#    return true if allNil == true # There were no filters specified at this depth
		return match
	end
	
	def parseRecordnk(offset, xmlNode, fqName, level)
		nkHash = REGISTRY_STRUCT_NK.decode(read_buffer(offset, SIZEOF_REGISTRY_STRUCT_NK))
		# Convert the type from hex to text
		nkHash[:type_display] = typeToString(nkHash[:type])
		# Get the keyname which is just beyond the structure
		nkHash[:keyname] = read_buffer(offset + SIZEOF_REGISTRY_STRUCT_NK,nkHash[:name_length]-1).chomp("\0")
		
		DumpHash.SortPrint(nkHash, :NK)

		#$log.debug "parseRecordNK [#{xmlNode}] [#{xmlNode.class}] [#{nkHash[:keyname]}] [#{nkHash[:type_display]}]"
		if nkHash[:type_display] == :SUB
			level += 1
      if fqName.nil?
        fqName = "#{nkHash[:keyname].chomp}"
      else
        fqName += "\\#{nkHash[:keyname].chomp}"
      end
			#$log.debug "Fully Q Name: [#{level}]  [#{nkHash['keyname'].chomp}]  [#{fqName}]"
			#Check sub-directory filters
			#return unless checkFilters(nkHash['keyname'].chomp.downcase, level-1)
			cf = checkFilters(nkHash[:keyname].chomp.downcase, fqName, level)
			#$log.debug "Fully Q Name: [#{"%5s" % cf}] [#{fqName}]  [#{level}]"
			#$log.debug "Fully Q Name: [#{fqName}]  [#{level}]"
			return unless cf
      #xmlSubNode = xmlNode
			xmlSubNode = xmlNode.add_element(:key, :keyname=>nkHash[:keyname].chomp, :fqname=>fqName)
      #on_start_element(:key, {:keyname=>nkHash[:keyname].chomp, :fqname=>fqName})
		else
			xmlSubNode = xmlNode
		end
		
		# Process all values
		if nkHash[:num_values] > 0 then
			vkOffset = nkHash[:values_offset]
			for i in 1..nkHash[:num_values]
				vkHash = REGISTRY_STRUCT_VK_OFFSET.decode(read_buffer(vkOffset,SIZEOF_REGISTRY_STRUCT_VK_OFFSET))
				parseRecord(vkHash[:offset_vk], xmlSubNode, fqName, level)
				vkOffset += SIZEOF_REGISTRY_STRUCT_VK_OFFSET
			end
		end
		
		# Process all subkeys
    if nkHash[:num_subkeys] > 0
      parseRecord(nkHash[:subkeys_offset], xmlSubNode, fqName, level)
    end

    #on_end_element(:key)
	end
	
	def parseRecordri(offset, xmlNode, fqName, level)
		#        $log.debug "parseRecordRI at offset #{offset}"
		riHash = REGISTRY_STRUCT_RI.decode(read_buffer(offset,SIZEOF_REGISTRY_STRUCT_RI))
		
		DumpHash.SortPrint(riHash, :RI)
		
		if riHash[:num_keys] > 0 then
			key_offset = offset + SIZEOF_REGISTRY_STRUCT_RI
			for i in 1..riHash[:num_keys]
				hash = REGISTRY_STRUCT_RI_OFFSET.decode(read_buffer(key_offset,SIZEOF_REGISTRY_STRUCT_RI_OFFSET))
				parseRecord hash[:offset_ri], xmlNode, fqName, level
				key_offset += SIZEOF_REGISTRY_STRUCT_RI_OFFSET
			end
		end
	end
	
	def parseRecordlf(offset, xmlNode, fqName, level)
		#$log.debug "parseRecordLF at offset #{offset}"
		lfHash = REGISTRY_STRUCT_LF.decode(read_buffer(offset,SIZEOF_REGISTRY_STRUCT_LF))
		
		if lfHash[:num_keys] > 0 then
			key_offset = offset + SIZEOF_REGISTRY_STRUCT_LF
			for i in 1..lfHash[:num_keys]
				hash = REGISTRY_STRUCT_LF_HASH.decode(read_buffer(key_offset,SIZEOF_REGISTRY_STRUCT_LF_HASH))
				parseRecord hash[:offset_nk], xmlNode, fqName, level
				key_offset += SIZEOF_REGISTRY_STRUCT_LF_HASH
			end
		end
	end
	
	def parseRecordlh(offset, xmlNode, fqName, level)
		#$log.debug "parseRecordLH at offset #{offset}"
		lhHash = REGISTRY_STRUCT_LH.decode(read_buffer(offset,SIZEOF_REGISTRY_STRUCT_LH))
		
		if lhHash[:num_keys] > 0 then
			key_offset = offset + SIZEOF_REGISTRY_STRUCT_LH
			for i in 1..lhHash[:num_keys]
				hash = REGISTRY_STRUCT_LH_HASH.decode(read_buffer(key_offset,SIZEOF_REGISTRY_STRUCT_LH_HASH))
				parseRecord hash[:offset_nk], xmlNode, fqName, level
				key_offset += SIZEOF_REGISTRY_STRUCT_LH_HASH
			end
		end
	end
	
	def parseRecordvk(offset, xmlNode, fqName, level)
		#$log.debug "parseRecordVK at offset #{offset}"
		vkHash = REGISTRY_STRUCT_VK.decode(read_buffer(offset,SIZEOF_REGISTRY_STRUCT_VK))
		vkHash[:data_type_display] = KEY_TYPES[vkHash[:data_type]]
		if vkHash[:name_length] == 0 then
			vkHash[:data_name] = "(Default)"
		else
			vkHash[:data_name] = read_buffer(offset + SIZEOF_REGISTRY_STRUCT_VK,vkHash[:name_length]-1)
		end

    # Check value filters here
    return if @filter_value && !@filter_value.has_key?(vkHash[:data_name].downcase)

		begin
      case vkHash[:data_type_display]
			when :REG_SZ, :REG_EXPAND_SZ then	vkHash[:data] = getRegString(vkHash, vkHash[:data_type_display])
			when :REG_DWORD    then vkHash[:data] = vkHash[:data_offset]
			when :REG_NONE     then vkHash[:data] = "(zero-length binary value)"
			when :REG_BINARY   then vkHash[:data] = getRegBinary(vkHash)
			when :REG_QWORD    then vkHash[:data] = read_buffer(vkHash[:data_offset], 8).unpack("Q").join.to_i
			when :REG_MULTI_SZ then vkHash[:data] = getRegMultiString(vkHash)
			else
				# Ignore types: REG_RESOURCE_REQUIREMENTS_LIST and REG_RESOURCE_LIS
				if DEBUG_UNHANDLED_DATA then
					$log.warn "Unhandled vk record type of [#{vkHash[:data_type]}] [#{vkHash[:data_type_display]}]" unless vkHash[:data_type] == 8 || vkHash[:data_type] == 10 || vkHash[:data_type] >= 12
				end
			end
			
		ensure
			DumpHash.SortPrint(vkHash, :VK)
      #xmlSubNode = xmlNode
			xmlSubNode = xmlNode.add_element(:value, :type=>vkHash[:data_type_display], :name=>vkHash[:data_name])
			xmlSubNode.text = vkHash[:data]
            
			# This is a performance hack right now since searching the whole xml doc for DigitalProductIds takes so long.
			@digitalProductKeys << xmlSubNode if vkHash[:data_name].downcase == "digitalproductid"
		end
	end
	
	def getRegMultiString(vkHash)
		begin
			#$log.debug sprintf("data offset: (0x%X)  Length: [%d]", vkHash['data_offset']+REG_DATA_OFFSET, vkHash['data_length'])
      if vkHash[:data_offset] < 0
        #$log.warn "Invalid offset for multi-string data Key:[#{fqName}] Value:[#{vkHash[:data_name]}] Offset:[#{vkHash[:data_offset]}]"
        return
      end
			vkHash[:data] = read_buffer(vkHash[:data_offset],vkHash[:data_length]-1)
			vkHash[:data].UnicodeToUtf8!.strip!
		ensure
			vkHash[:data].tr!("\0", "\n") unless vkHash[:data].nil?
		end    
	end
	
	def getRegString(vkHash, key_type)
    #$log.debug sprintf("data offset: (0x%X)  Length: [%d]", vkHash['data_offset']+REG_DATA_OFFSET, vkHash['data_length'])
    if (vkHash[:data_length] & 0x80000000) == 0 then
      vkHash[:data] = read_buffer(vkHash[:data_offset], vkHash[:data_length]-1)
      begin
        vkHash[:data].UnicodeToUtf8!
      rescue
        # Since we are getting Unicode strings out of the registry they should be even numbers lengths
        if vkHash[:data_length].remainder(2) == 1
          vkHash[:data] = read_buffer(vkHash[:data_offset], vkHash[:data_length]-2)
          vkHash[:data].UnicodeToUtf8!
        else
          raise $!
        end
      end
    else
      vkHash[:data] = (vkHash[:data_offset] & 0xFF).chr
    end

    # Truncate string at the first null character
    if i = vkHash[:data].index("\0") then
      vkHash[:data] = vkHash[:data][0...i]
    end

    # Resolve expand keys
    @expandEnv.each_pair { |k,v| vkHash[:data].gsub!(k, v) } if key_type == :REG_EXPAND_SZ

    return vkHash[:data]
	end
    
	def getRegBinary(vkHash)
		if (vkHash[:data_length] & 0x80000000) == 0 then
      res = self.class.rawBinaryToRegBinary(read_buffer(vkHash[:data_offset], vkHash[:data_length]-1))
		else
			res = vkHash[:data_offset].to_s(16).rjust(8, '0')
			res = "#{res[6..7]},#{res[4..5]},#{res[2..3]},#{res[0..1]}"
		end

    return res
	end
	
	def validateRegFile(fileName)
    t0 = Time.now
		# Do some basic file validation

    fileObj = @fs ? @fs : File
    raise "Registry file [#{fileName}] does not exist." if fileObj.send(@fs ? :fileExists? : :exist?, fileName) == false
    regSize = fileObj.send(@fs ? :fileSize : :size, fileName)
    raise "Registry file [#{fileName}] is empty." if regSize.zero?
    @fileHnd = fileObj.send(@fs ? :fileOpen : :open, fileName, 'rb')
    regf_buf = read_hbin(0)

    raise "Registry file [#{fileName}] does not contain valid marker." if regf_buf[0,4] != "regf"
    $log.info  "Reading #{fileName} with size (#{regSize})" if DEBUG_PRINT

		# Read in Registry header
		head_string = regf_buf[0, SIZEOF_REGISTRY_HEADER_REGF]
		raise "Registry hive [#{fileName}] does not contain a valid header." unless head_string
		@hiveHash = REGISTRY_HEADER_REGF.decode(head_string)
		@hiveHash[:name].UnicodeToUtf8!.strip!

		# Dump sorted hash results
		DumpHash.SortPrint(@hiveHash, :REGF)

		$log.info "Registry hive [#{File.basename(@hiveHash[:name])}] successfully opened for reading in [#{Time.now-t0}] seconds.  Size:[#{regSize}]  Last registry update: [#{MSRegHive.wtime2time(@hiveHash[:timestamp])}]"
	end
	
	def typeToString(type)
		case
		when type == 44 then :ROOT
		when type == 32 then :SUB
		when type == 4128 then :SUB
		when type == 16 then :LINK
		else                 :UNKNOWN
		end
	end
  	
	def self.wtime2time(wtime)
		begin
			Time.at((wtime - 116444736000000000) / 10000000).getutc
		rescue RangeError
			return nil
		end
	end

	def self.isRegBinary(data)
		data =~ /^[0-9a-fA-F]{2}(,[0-9a-fA-F]{2})*$/
  end

	def self.regBinaryToRawBinary(data)
		raise ArgumentError unless isRegBinary(data)
    return [data.delete(',')].pack("H*")
  end

  def self.rawBinaryToRegBinary(data)
    return data.unpack("H*")[0].scan(/../).join(',')
  end
	
	def getHash
		return @hiveHash
	end

  def read_buffer(start_offset, data_length)
    # Adjust offset so it matches the length of the actual registry hive file.
    start_offset += REG_DATA_OFFSET

    # Find what hbin section this data is in.  Also loads data from file if it is not already in memory
    idx = self.load_sections(start_offset / HBIN_SIZE)

    # Subtract the section offset from the full offset to get the position inside the buffer
    return @hbin[idx][start_offset-(idx * HBIN_SIZE), data_length+1]
  end

  def load_sections(idx)
    if @hbin.has_key?(idx)
      @stats[:cache_hits]+=1 if DEBUG_FILE_READS
      # If the hash points to data return its index.  Otherwise the hash
      # will point to the index of the starting block of data
      return @hbin[idx].kind_of?(Integer) ? @hbin[idx] : idx
    else
      @hbin[idx] = read_hbin(idx)
      binHash = REGISTRY_STRUCT_HBIN.decode(@hbin[idx][0, SIZEOF_REGISTRY_STRUCT_HBIN])

      unless binHash[:id] == 'hbin'
        # If the block does not start with the header sign then back up and find it so
        # we can load the full hbin which spans several block
        while binHash[:id] != 'hbin'
          binHash = REGISTRY_STRUCT_HBIN.decode(read_hbin(idx-=1)[0, SIZEOF_REGISTRY_STRUCT_HBIN])
        end
      end

      # Determine if the hbin is more than one block
      hbin_count = binHash[:offset_to_next] / HBIN_SIZE
      if hbin_count > 1
        @hbin[idx] = read_hbin(idx, hbin_count)
        # Set contiguous blocks with the index of the starting block
        (idx+1).upto(idx+hbin_count-1) {|i| @hbin[i]=idx}
      end
      return idx
    end
  end

  def read_hbin(idx, count=1)
    startAddr = idx * HBIN_SIZE
    readCount = (HBIN_SIZE * count)
    if DEBUG_FILE_READS
      @stats[:file_reads]+=1
      @stats[:bytes_read]+=readCount
    end
    @fileHnd.seek(startAddr, IO::SEEK_SET)
    @fileHnd.read(readCount)
  end

  #  def on_start_element(name, attr_hash)
  #    $log.warn "START KEY: fqName:#{fqName}"
  #  end
  #
  #  def on_end_element(name)
  #    $log.warn "END   KEY: fqName:#{fqName}"
  #  end
	
	#define registry structures
	REGISTRY_HEADER_REGF = BinaryStruct.new([
		'a4',			:id,										# ASCII "regf" = 0x66676572
		'i',			:updates1,							# update counter 1
		'i',			:updates2,							# update counter 2
		'Q',			:timestamp,						# last modified (WinNT format)
		'i',			:version_major,				# Version - Major Number
		'i',			:version_minor,				# Version - Minor Number
		'i',			:version_release,			# Version - Release Number
		'i',			:version_build,				# Version - Build Number
		'i',			:data_offset,					# Data offset
		'i',			:last_block,						# Offset of Last Block
		'i',			nil,										# UNKNOWN for 4	=1
		'a64',		:name,									# description - last 31 characters of Fully Qualified Hive Name (in Unicode)
		'a396',		nil,										# UNKNOWN x396
		'i',			:checksum,							# checksum of all DWORDS (XORed) from 0x0000 to 0x01FB
	])
	SIZEOF_REGISTRY_HEADER_REGF = REGISTRY_HEADER_REGF.size
	
	REGISTRY_STRUCT_HBIN = BinaryStruct.new([
		'a4',			:id,										# ASCII "hbin" = 0x6E696268
		'i',			:offset_from_first,		# Offset from 1st hbin-Block
		'i',			:offset_to_next,				# Offset to the next hbin-Block
		'Q',			nil,										# UNKNOWN for 8
		'Q',			:timestamp,						# last modified (WinNT format)
		'i',			:block_size,						# Block size (including the header!)
		'l',			:length,								# Negative if not used, positive otherwise.	Always a multiple of 8
	])
	SIZEOF_REGISTRY_STRUCT_HBIN = REGISTRY_STRUCT_HBIN.size
	
	REGISTRY_STRUCT_NK = BinaryStruct.new([
		'a2', 		:id,										# ASCII "nk" = 0x6B6E
		's',			:type,									# REG_ROOT_KEY = 0x2C, REG_SUB_KEY = 0x20, REG_SYM_LINK = 0x10
		'Q',			:timestamp,
		'a4',			nil,										# UNKNOWN						 
		'i',			:parent_offset,				# Offset of Owner/Parent key
		'V',			:num_subkeys,					# Number of Subkeys
		'a4',			nil,										# UNKNOWN
		'i',			:subkeys_offset,
		'i',			:unknown_offset,
		'i',			:num_values,
		'i',			:values_offset,				# Points to a list of offsets of vk-records
		'i',			:sk_offset,
		'i',			:classname_offset,
		'a20',		nil,										# UNKNOWN
		's',			:name_length,
		's',			:classname_length,
	])
	SIZEOF_REGISTRY_STRUCT_NK = REGISTRY_STRUCT_NK.size
	
	#		# Subkey listing with hash of first 4 characters
	REGISTRY_STRUCT_LH = BinaryStruct.new([
		'a2',			:id,										# ASCII "lh" = 0x666E
		's',			:num_keys,							# number of keys
	])
	SIZEOF_REGISTRY_STRUCT_LH = REGISTRY_STRUCT_LH.size
	
	#		# The vk-record consists information to a single value (value key).
	REGISTRY_STRUCT_VK = BinaryStruct.new([
		'a2',			:id,										# ASCII "vk" = 0x6B76
		's',			:name_length,
		'i',			:data_length,					# If top-bit set, offset contains the data
		'i',			:data_offset,
		'i',			:data_type,
		's',			:flag,									# =1, has name, else no name (=Default).
		'a2',			nil,										# UNKNOWN
	])
	SIZEOF_REGISTRY_STRUCT_VK = REGISTRY_STRUCT_VK.size
	
	REGISTRY_STRUCT_LH_HASH = BinaryStruct.new([#		set STRUCT(REC-LH-HASH) {
		'i',			:offset_nk,						# offset of corresponding NK record
		'a4',			:keyname,							# Key Name
	])
	SIZEOF_REGISTRY_STRUCT_LH_HASH = REGISTRY_STRUCT_LH_HASH.size
	
	REGISTRY_STRUCT_VK_OFFSET = BinaryStruct.new([#		set STRUCT(REC-LH-HASH) {
		'i',			:offset_vk,						# offset of corresponding NK record
	])
	SIZEOF_REGISTRY_STRUCT_VK_OFFSET = REGISTRY_STRUCT_VK_OFFSET.size
	
	# The lf-record is the counterpart to the RGKN-record (the hash-function)
	REGISTRY_STRUCT_LF = BinaryStruct.new([
		'a2',			:id,										# ASCII "lf" = 0x666C
		's',			:num_keys,							# number of keys
	])
	SIZEOF_REGISTRY_STRUCT_LF = REGISTRY_STRUCT_LF.size
	
	REGISTRY_STRUCT_LF_HASH = BinaryStruct.new([
		'i',			:offset_nk,						# offset of corresponding NK record
		'a4',			:keyname,							# Key Name
	])
	SIZEOF_REGISTRY_STRUCT_LF_HASH = REGISTRY_STRUCT_LF_HASH.size
	
	# A list of offsets to LI/LH records
	REGISTRY_STRUCT_RI = BinaryStruct.new([
		'a2',			:id,										# ASCII "ri" = 0x6972
		's',			:num_keys,							# number of keys
	])
	SIZEOF_REGISTRY_STRUCT_RI = REGISTRY_STRUCT_RI.size
	
	REGISTRY_STRUCT_RI_OFFSET = BinaryStruct.new([#		set STRUCT(REC-LH-HASH) {
		'i',			:offset_ri,						# offset of corresponding NK record
	])
	SIZEOF_REGISTRY_STRUCT_RI_OFFSET = REGISTRY_STRUCT_RI_OFFSET.size
	
  #
  #		# sk (? Security Key ?) is the ACL of the registry.
  #		set STRUCT(REC-SK) {
  #				a2	id										/* ASCII "sk" = 0x6B73 */
  #				s		tag										/* */
  #				i		prev_offset						/* Offset of previous "sk"-Record */
  #				i		next_offset						/* Offset of next "sk"-Record */
  #				i		ref_count							/* Reference/Usage counter */
  #				i		rec_size							/* Record size */
  #		}

	# Return registry key type. Otherwise return the hex value of the integer
	KEY_TYPES = Hash.new { |h, k| "%08X" % k }
  KEY_TYPES.merge!({
			0 =>  :REG_NONE,              # No value type
			1 =>  :REG_SZ,                # A null-terminated string (Unicode)
			2 =>  :REG_EXPAND_SZ,         # A null-terminated string that contains
			#  unexpanded references to environment variables (for example, "%PATH%"). 
			#  It will be a Unicode or ANSI string depending on whether you use the 
			#  Unicode or ANSI functions. To expand the environment variable references, 
			#  use the ExpandEnvironmentStrings function.
			3 =>  :REG_BINARY,            # Free form binary
			4 =>  :REG_DWORD,             # 32-bit number - Little Endian
			5 =>  :REG_DWORD_BIG_ENDIAN,  # 32-bit number - Big Endian
			6 =>  :REG_LINK,              # Symbolic Link (unicode) - Reserved for system use.
			7 =>  :REG_MULTI_SZ,          # A sequence of null-terminated strings, terminated by an empty string (\0).
			# The following is an example:
			#   String1\0String2\0String3\0LastString\0\0
			# The first \0 terminates the first string, the second to the last \0 terminates the last string, 
			# and the final \0 terminates the sequence. Note that the final terminator must be factored into the length of the string.
			8 =>  :REG_RESOURCE_LIST,     # Resource list in the resource map
			9 =>  :REG_FULL_RESOURCE_DESCRIPTOR,  # Resource list in the hardware description
			10 => :REG_RESOURCE_REQUIREMENTS_LIST,
			11 => :REG_QWORD,             # 64-bit number - Little Endian
		})
end

module DumpHash
	def DumpHash.SortPrint(hash, prefix = :UKN)
    return unless DEBUG_PRINT
		$log.debug "#{prefix}(RAW): ========"
    hash.sort{|a,b| a.to_s<=>b.to_s}.each {|x,y| $log.debug "#{prefix}(#{x})\t\t= #{y}"}
	end
end
