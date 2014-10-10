# encoding: US-ASCII

require 'stringio'

$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'
require 'miq-unicode'

# Notes:
#       The peheader object member 'icons' is an array of icons in the file. Sub 0 is the application 
#       icon, 1 is usually the document icon.  The format is the same as an .ico file.  The simple test 
#       writes found icons to the root dir as icon0.ico, icon1.ico, etc.  Any icon editor will be able 
#       to open them and display each resolution contained in the icon (if more than one).

# Bit test extension to Fixnum & Bignum.
class Fixnum
	# Returns state of bit number bitNum in self.
	def bit?(bitNum)
		msk = 1 << bitNum
		return self & msk == msk
	end
end

class Bignum
	# Returns state of bit number bitNum in self.
	def bit?(bitNum)
		msk = 1 << bitNum
		return self & msk == msk
	end
end

class PEheader

IMAGE_NT_SIGNATURE = "PE\0\0"
IMAGE_DOS_SIGNATURE = "MZ"
	
  attr_reader :imports, :icons, :messagetables, :versioninfo

  def initialize(path)
    @fname = path
    @dataDirs = Array.new
    @sectionTable = Array.new

    if path.class != String then
      @fHnd = path
      self.fileseek(0, 'init')
      fBuf = self.fileread(2)
    else
      # Do some basic file validation
      raise Errno::ENOENT, "File [#{@fname}] does not exist." if File.exist?(@fname) == false
      raise "File [#{@fname}] is empty." if File.zero?(@fname)

      # Open file and read contents into buffer
      @fHnd = File.open(@fname, "rb")
      fBuf = fileread(2)
      @fHnd.close
    end
    
    # Check for the MZ header
    raise "Version Information header not found in file [#{@fname}]" unless fBuf[0..1] == IMAGE_DOS_SIGNATURE
    
    readPE()
  end

  def readPE
    if @fname.class != String then
      @fHnd = @fname
      fileseek(0, 'readPE')
    else
      # Open file
      @fHnd = File.open(@fname, "rb")
    end

    # Read contents into buffer
    #TODO: determine the proper amount of data to load here
    @fBuf = fileread(10240)

    # Read offsets for next string
    dhHash = IMAGE_DOS_HEADER.decode(@fBuf)
    offset = dhHash['e_lfanew'] # Offset to PE header
    raise "PE header not found in file [#{@fname}]" unless @fBuf[offset...offset+4] == IMAGE_NT_SIGNATURE
    offset += 4
    fhHash = IMAGE_FILE_HEADER.decode(@fBuf[offset..-1])
    offset += SIZEOF_IMAGE_FILE_HEADER

    @is64Bit = fhHash['SizeOfOptionalHeader'] == IMAGE_SIZEOF_NT_OPTIONAL64_HEADER
    @IMAGE_OPTIONAL_HEADER = (@is64Bit == true) ? IMAGE_OPTIONAL_HEADER64 : IMAGE_OPTIONAL_HEADER32

    # Commented out the following, since it is not currently being used.
    #ohHash = @IMAGE_OPTIONAL_HEADER.decode(@fBuf[offset, @IMAGE_OPTIONAL_HEADER.size])

    # Read all the data directories & section table.
    offset = getDataDirs(@fBuf, offset)
    offset = getSectionTable(@fBuf, fhHash, offset)
  end

  # These file methods are here to assist in debugging
  def fileseek(offset=0, message=nil)
    #st = Time.now
    @fHnd.seek(offset, IO::SEEK_SET)
    #$log.warn "seek time [#{Time.now-st}] from [#{message}]" if $log
  end

  def fileread(length)
    #st = Time.now
    data = @fHnd.read(length)
    #$log.warn "read time [#{Time.now-st}]" if $log
    return data
  end

  def imports
    @import_array || @import_array = getImports()
  end
  
  def icons
    @icon_array || @icon_array = getIcons(@fBuf)
  end

  def messagetables
    @messagetable_hash || @messagetable_hash = getMessagetables()
  end
  
  def versioninfo
    @versioninfo_array || @versioninfo_array = getVersioninfo()
  end
  
	#//////////////////////////////////////////////////////////////////////////
	#//
	
	def getDataDirs(fBuf, offset)
		offset += @IMAGE_OPTIONAL_HEADER.size
    IMAGE_NUMBEROF_DIRECTORY_ENTRIES.times do
      ddHash = IMAGE_DATA_DIRECTORY.decode(fBuf[offset..-1])
      offset += SIZEOF_IMAGE_DATA_DIRECTORY
      @dataDirs.push(ddHash)
    end
		return offset
	end
	
	def getSectionTable(fBuf, fhHash, offset)
    fhHash['NumberOfSections'].times do
      shHash = IMAGE_SECTION_HEADER.decode(fBuf[offset..-1])
      offset += SIZEOF_IMAGE_SECTION_HEADER
      @sectionTable.push(shHash)
    end
		return offset
	end
	
	def getImports()
		imports_libs = []
    import = @dataDirs[IMAGE_DIRECTORY_ENTRY_IMPORT]
    import[:offset] = import[:virtualAddress]
    if import[:offset] != 0 then
      import[:offset] = adjustAddress(import[:offset])
      fileseek(import[:offset], 'getImports')
      data = fileread(import[:size])
      offset = 0
      loop do
        iiHash = IMAGE_IMPORT_DESCRIPTOR.decode(data[offset..-1])
        break if iiHash['Name'] == 0
        offset += SIZEOF_IMAGE_IMPORT_DESCRIPTOR
        iiHash['Name'] = adjustAddress(iiHash['Name']) - import[:offset]

        # Check if we have enough data.  This happens if the import data only contains pointers
        if (data.length <= iiHash['Name'])
          size = iiHash['Name'] - data.length + 4096
          data += fileread(size)
        end

        nameEnd = iiHash['Name'] + data[iiHash['Name']..-1].index("\0") -1
        imports_libs.push(data[iiHash['Name']..nameEnd].downcase)
      end
    end
		return imports_libs
	end
	
	def getIcons(fBuf)
		iconEntries = getRawIcons(fBuf)
		grpIcons = getIconDirEntries(fBuf)
		return assembleIcons(iconEntries, grpIcons)
	end
	
	def getRawIcons(fBuf)
		# Read raw icons.
    iconEntries = []
    get_resources_by_type(RT_ICON) do |icon_rsc|
      ent = icon_rsc[:data]
      ent[:offset] = adjustAddress(ent[:offsetToData])
      fileseek(ent[:offset], 'getRawIcons')
			icon_rsc[:icon] = fileread(ent[:size])
      iconEntries << icon_rsc
    end
		return iconEntries
	end
	
	def getIconDirEntries(fBuf)
		# Read icon directory.
		grpIcons = []
		#iconDirEntries = getDataEntries(RT_GROUP_ICON, fBuf)
    get_resources_by_type(RT_GROUP_ICON) do |icon_rsc|
      ent = icon_rsc[:data]
      ent[:offset] = adjustAddress(ent[:offsetToData])
      fileseek(ent[:offset], 'getIconDirEntries')
      iconDir = fileread(ent[:size])
      iconDir = GRPICONDIR.decode(iconDir)
      grpIconDirEntries = []
      0.upto(iconDir[:idCount] - 1) {|i| grpIconDirEntries << GRPICONDIRENTRY.decode(iconDir[:data][i * SIZEOF_GRPICONDIRENTRY, SIZEOF_GRPICONDIRENTRY])}
      grpIcons << grpIconDirEntries
    end
		return grpIcons
	end
	
	def assembleIcons(iconEntries, grpIcons)
		# For each major sub in grpIcons, construct an .ico blob.
		icons = []
		0.upto(grpIcons.size - 1) do |fileIdx|
			# Write icon directory.
			baseOffset = 16 * grpIcons[fileIdx].size + 6
			thisOffset = 0
			ico = StringIO.new
			ico.write([0].pack('S'))											#idReserved
			ico.write([1].pack('S'))											#idType
			ico.write([grpIcons[fileIdx].size].pack('S')) #idCount
			0.upto(grpIcons[fileIdx].size - 1) do |iconIdx|
				icon = grpIcons[fileIdx][iconIdx]
				# Write icon dir entry.
				ico.write([icon[:bWidth]].pack('C'))
				ico.write([icon[:bHeight]].pack('C'))
				ico.write([icon[:bColorCount]].pack('C'))
				ico.write([0].pack('C'))
				ico.write([icon[:wPlanes]].pack('S'))
				ico.write([icon[:wBitCount]].pack('S'))
				ico.write([icon[:dwBytesInRes]].pack('L'))
				ico.write([baseOffset + thisOffset].pack('L'))
				thisOffset += icon[:dwBytesInRes]
      end
			# Write icon data.
			0.upto(grpIcons[fileIdx].size - 1) {|iconIdx| ico.write(getIconById(iconEntries, grpIcons[fileIdx][iconIdx][:nID]))}
			# Save it as a string.
			ico.rewind
			icons << ico.read()
		end
		return icons
	end
	
	# Find a particular raw icon.
	def getIconById(icons, id)
		icons.each {|icon| return icon[:icon] if icon[:rsc_id] == id}
		return nil
	end
	
  def getMessagetables(requested_locale=0x0409)
    # Read message table resources.
    messagetables = {}
    get_resources_by_type(RT_MESSAGETABLE, requested_locale) do |msg_resource|
      # Get the block directory for this messagetable.
      msg_data = msg_resource[:data]
      offset = adjustAddress(msg_data[:offsetToData]) - @dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:offset]
      blkdir = MESSAGE_RESOURCE_DATA.decode(@dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:data][offset, msg_data[:size]])
      0.upto(blkdir[:numberOfBlocks] - 1) do |i|

        # Break out each block.
        blk = MESSAGE_RESOURCE_BLOCK.decode(blkdir[:data][i * SIZEOF_MRB, SIZEOF_MRB])
        adrs = blk[:offsetToEntries] - 4

        # Grab the block's strings.
        blk[:loId].upto(blk[:hiId]) do |idx|
          ent1 = MESSAGE_RESOURCE_ENTRY.decode(blkdir[:data][adrs, SIZEOF_MRE])
          if ent1[:length] > 0
            len = ent1[:length] - SIZEOF_MRE
            str = blkdir[:data][adrs + SIZEOF_MRE, len]
            (ent1[:flags] == MESSAGE_RESOURCE_UNICODE) ? str.UnicodeToUtf8! : str.AsciiToUtf8!
            str.gsub!(/\000/, "")
            messagetables[idx] = str
            adrs += len
          end
          adrs += SIZEOF_MRE
        end
      end
    end
    return messagetables
  end

	# Get versioninfo resource.
	def getVersioninfo(requested_locale=0x0409)
		aVersioninfoHash = {}
    get_resources_by_type(RT_VERSION, requested_locale) do |versionEntry|
      ent = versionEntry[:data]
      offset = adjustAddress(ent[:offsetToData]) - @dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:offset]
			versionInfo = @dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:data][offset, ent[:size]]
			# versionInfo is a VS_FIXEDFILEINFO structure followed by StringFileInfo.
      aVersioninfoHash = getVersionInfoHash(versionInfo)
    end
		return aVersioninfoHash
	end

  # Walk the resource directories and collect all the directories and resource pointers
  def getDataEntries(fBuf, rsc_id=nil)
    result={}
    getBaseResDir(fBuf) {|baseResDir| dumpResourceDirectory(baseResDir, 0, result, rsc_id)}
    return result
  end

  def dumpResourceDirectory(resDir, level, data_hash, rsc_id=nil)
    resDirEntry = getResourceDirectoryEntry(resDir)

    # Process each entry in the directory.
    # Note: Named entries are listed first.
    1.upto(resDir[:numberOfNamedEntries]) do
      dumpResourceEntry(resDirEntry, level+1, data_hash, rsc_id)
      resDirEntry = getNextResourceDirectoryEntry(resDirEntry)
    end

    1.upto(resDir[:numberOfIdEntries]) do
      dumpResourceEntry(resDirEntry, level+1, data_hash, rsc_id)
      resDirEntry = getNextResourceDirectoryEntry(resDirEntry)
    end
  end

  def dumpResourceEntry(resDirEntry, level, data_hash, rsc_id)
    #1.upto(level) {print "  "}

    resDirEntry[:name] = getResourceDirectoryEntryName(resDirEntry)
    resDirEntry[:level] = level
    if resDirEntry[:isDir]

      # Filter by resource type so we do not process every available resource
      return if level == 1 && rsc_id && resDirEntry[:name] != rsc_id

      resDir = getResourceDirectory(resDirEntry)
      resDirEntry[:numberOfIdEntries] = resDir[:numberOfIdEntries]
      resDirEntry[:numberOfNamedEntries] = resDir[:numberOfNamedEntries]
      #puts "DIR: #{resDirEntry.inspect}"
      
      data_hash[resDirEntry[:name]] = resDirEntry
      resDirEntry[:children] = {}

      dumpResourceDirectory(resDir, level, resDirEntry[:children], rsc_id)
    else
      data_hash[resDirEntry[:name]] = resDirEntry
			resDirEntry[:data] = IMAGE_RESOURCE_DATA_ENTRY.decode(@dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:data][resDirEntry[:offsetToData]..-1])
      #puts "RSC: #{resDirEntry.inspect}"
    end
  end

  def getResourceDirectory(resDirEntry)
    offset = resDirEntry[:offsetToData] & 0x7fffffff
    resDir = IMAGE_RESOURCE_DIRECTORY.decode(@dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:data][offset..-1])
    resDir[:offset_into_data] = offset
    return resDir
  end

  def getResourceDirectoryEntry(resDir)
    getNextResourceResourceEntry(resDir, IMAGE_RESOURCE_DIRECTORY_ENTRY, SIZEOF_IMAGE_RESOURCE_DIRECTORY)
  end

  def getNextResourceDirectoryEntry(resDirEntry)
    getNextResourceResourceEntry(resDirEntry, IMAGE_RESOURCE_DIRECTORY_ENTRY, SIZEOF_IMAGE_RESOURCE_DIRECTORY_ENTRY)
  end

  def getNextResourceResourceEntry(resEntry, rsc_type, size)
    offset = resEntry[:offset_into_data] + size
    entry = rsc_type.decode(@dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:data][offset..-1])
    entry[:offset_into_data] = offset
    entry[:isDir] = entry[:offsetToData].bit?(31)
    return entry
  end

	def getBaseResDir(fBuf)
    if @baseResDir.nil?
      rsc = @dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE]
      rsc[:offset] = rsc[:virtualAddress]
      unless rsc[:offset].zero?
        rsc[:offset] = adjustAddress(rsc[:offset])
        # Read in the resource part the file
        fileseek(rsc[:offset], 'getBaseResDir')
        rsc[:data] = fileread(rsc[:size])
        @baseResDir = IMAGE_RESOURCE_DIRECTORY.decode(rsc[:data][0, SIZEOF_IMAGE_RESOURCE_DIRECTORY])
        @baseResDir[:offset_into_data] = 0
      end
    end
		yield(@baseResDir) unless @baseResDir.nil?
	end

  def get_resources_by_type(rt, locale_id=nil)
    if (rsc = getDataEntries(@fBuf, rt)[rt])
      resources = []
      find_all_resources(rsc[:children]) {|r| resources << r}
      return if resources.empty?

      # Finding a resource is often by locale.  If we do not find the requested
      # locale then return the first one.
      unless locale_id.nil?
        local_rsc = resources.detect {|r| r[:lang_id]==locale_id}
        resources = local_rsc.nil? ? [resources.first] : [local_rsc]
      end

      # Yield the resource data to the caller
      resources.each {|r| yield(r)}
    end
  end

  def find_all_resources(rsc, rsc_id=nil, &blk)
    # Resource Directory Levels:
    # 1 = Resource Type
    # 2 = Resource Identifier
    # 3 = Resource Langauge ID
    rsc.each do |lang_id, item|
      if item[:isDir]
        rsc_id = item[:name] if item[:level]==2
        find_all_resources(item[:children], rsc_id, &blk)
      else
        item[:rsc_id]  = rsc_id
        item[:lang_id] = lang_id
        yield(item)
      end
    end
  end
	
	def getResourceDirectoryEntryName(resDirEntry)
    return resDirEntry[:name] unless resDirEntry[:name].bit?(31)

		# The low 30 bits of the 'Name' member is an offset to an IMAGE_RESOURCE_DIRECTORY_STRING_U struct.
		str = ""
		ptr = (resDirEntry[:name] & 0x7fffffff)
		len = @dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:data][ptr, 2].unpack('S')[0]
		str = @dataDirs[IMAGE_DIRECTORY_ENTRY_RESOURCE][:data][ptr + 2, len*2]
		return str.UnicodeToUtf8!
	end
	
	def adjustAddress(rva)
    @sectionTable.each do |s|
      # Is the RVA within this section?
      if ( (rva >= s[:virtualAddress]) && (rva < (s[:virtualAddress] + s[:VirtualSize]))) then
        delta = s[:virtualAddress] - s[:PointerToRawData]
	      return rva - delta
      end
    end
    return nil
  end
  
  def getImportList
    return nil if self.imports.nil?
    unless self.imports.empty?
      import_list = ""
      self.imports.each {|i| import_list += i + ", "}
      return import_list.rstrip.chomp(",")
    end
  end

  def getVersionInfoHash(fBuf)
    viHash = Hash.new
    
    # Find VS Version Info signature
    idx = fBuf.index(VS_VERSION_INFO)
    return viHash unless idx
    #raise "Version Information header not found in file" unless idx
    #$log.debug sprintf("Found at index: [0X%08X] (%d)", idx, idx)

    # Reduce buffer to just the signature to the end of the file
    fBuf = fBuf[idx..fBuf.length]
    offset = 0
    vhHash = VS_VERSION_INFO_HEADER.decode(fBuf[offset..(offset + SIZEOF_VS_VERSION_INFO_HEADER)])

    # Create VersionInfo hash
    viHash['FILEVERSION_HEADER']    = vhHash['fmajor'].to_s + "," + vhHash['fminor'].to_s + "," + vhHash['frev'].to_s + "," + vhHash['fbuild'].to_s
    viHash['PRODUCTVERSION_HEADER'] = vhHash['pmajor'].to_s + "," + vhHash['pminor'].to_s + "," + vhHash['prev'].to_s + "," + vhHash['pbuild'].to_s

    # Find the string file info signautre
    idx = fBuf.index(STRINGFILEINFO)
    return viHash unless idx
    #raise "String File information header not found in file [#{fname}]" unless idx
    
    offset = idx
    viEnd = offset + SIZEOF_STRING_INFO_HEADER
    viHash.merge!(STRING_INFO_HEADER.decode(fBuf[offset..viEnd]))
    viHash['sig'].UnicodeToUtf8!.tr!("\0", "")
    viHash['code_page'].UnicodeToUtf8!.tr!("\0", "")
    viHash['lang'].UnicodeToUtf8!.tr!("\0", "")

    # Read offsets for next string
    offset = viEnd
    vsHash = VERSION_STRING_HEADER.decode(fBuf[offset..offset+6])

    # Calculate the amount of version info data
    offset_end = offset + viHash['data_length'] - SIZEOF_STRING_INFO_HEADER

    while offset < offset_end do
      break unless vsHash['zero'] == 0
      break if vsHash['zero'] == nil || vsHash['vlen'] == nil || vsHash['slen'] == nil
      offset += SIZEOF_VERSION_STRING_HEADER
      name_len = vsHash['slen'] - 4 - (vsHash['vlen']*2) - 2
      name = fBuf[offset...offset+name_len]
      offset += name_len
      value_len = (vsHash['vlen']*2)-2
      value = fBuf[offset...offset+value_len]
      break if name.nil? or value.nil? or name.empty?
      name.UnicodeToUtf8!.gsub!("\0", "")
      # Do not allow spaces in the attribute names (will invalidate a XML file)
      name.gsub!(" ", "_")
      value.UnicodeToUtf8!.gsub!("\0", "")
      #$log.debug "[#{name}] => [#{value}]"
      viHash[name] = value
      offset += value_len + (vsHash['vlen']%2*2)

      # Read next offset header
      vsHash = VERSION_STRING_HEADER.decode(fBuf[offset..offset+6])

      # This is a work-around.  In case the offset to the next record is slightly off
      unless vsHash['zero'] == 0
        offset -= 2
        # Read next offset header
        vsHash = VERSION_STRING_HEADER.decode(fBuf[offset..offset+6])
      end
    end

    return viHash
  end
	
################################################################
#  PE Header structures defined
################################################################
# From WINNT.H
#
#// Directory Entries
#
#// Export Directory
IMAGE_DIRECTORY_ENTRY_EXPORT      = 0
#// Import Directory
IMAGE_DIRECTORY_ENTRY_IMPORT      = 1
#// Resource Directory
IMAGE_DIRECTORY_ENTRY_RESOURCE    = 2
#// Exception Directory
IMAGE_DIRECTORY_ENTRY_EXCEPTION   = 3
#// Security Directory
IMAGE_DIRECTORY_ENTRY_SECURITY    = 4
#// Base Relocation Table
IMAGE_DIRECTORY_ENTRY_BASERELOC   = 5
#// Debug Directory
IMAGE_DIRECTORY_ENTRY_DEBUG       = 6
#// Description String
IMAGE_DIRECTORY_ENTRY_COPYRIGHT   = 7
#// Machine Value (MIPS GP)
IMAGE_DIRECTORY_ENTRY_GLOBALPTR   = 8
#// TLS Directory
IMAGE_DIRECTORY_ENTRY_TLS         = 9
#// Load Configuration Directory
IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG = 10

IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16


# From WinUser.h
#/*
# * Predefined Resource Types
# */
RT_CURSOR       = 1
RT_BITMAP       = 2
RT_ICON					= 3
RT_MENU         = 4
RT_DIALOG       = 5
RT_STRING       = 6
RT_FONTDIR      = 7
RT_FONT         = 8
RT_ACCELERATOR  = 9
RT_RCDATA       = 10
RT_MESSAGETABLE	= 11
RT_GROUP_ICON		= 14
RT_VERSION			= 16

IMAGE_FILE_HEADER = BinaryStruct.new([
    'v',   'Machine',
    'v',   'NumberOfSections',
    'V',   'TimeDateStamp',
    'V',   'PointerToSymbolTable',
    'V',   'NumberOfSymbols',
    'v',   'SizeOfOptionalHeader',
    'v',   'Characteristics',
])
SIZEOF_IMAGE_FILE_HEADER = IMAGE_FILE_HEADER.size

IMAGE_DOS_HEADER = BinaryStruct.new([       #// DOS .EXE header
    'v',   'e_magic',                     #// Magic number
    'v',   'e_cblp',                      #// Bytes on last page of file
    'v',   'e_cp',                        #// Pages in file
    'v',   'e_crlc',                      #// Relocations
    'v',   'e_cparhdr',                   #// Size of header in paragraphs
    'v',   'e_minalloc',                  #// Minimum extra paragraphs needed
    'v',   'e_maxalloc',                  #// Maximum extra paragraphs needed
    'v',   'e_ss',                        #// Initial (relative) SS value
    'v',   'e_sp',                        #// Initial SP value
    'v',   'e_csum',                      #// Checksum
    'v',   'e_ip',                        #// Initial IP value
    'v',   'e_cs',                        #// Initial (relative) CS value
    'v',   'e_lfarlc',                    #// File address of relocation table
    'v',   'e_ovno',                      #// Overlay number
    'v',   nil,                           #// Reserved words - e_res[4]
    'v',   nil,                           #// Reserved words - e_res[4]
    'v',   nil,                           #// Reserved words - e_res[4]
    'v',   nil,                           #// Reserved words - e_res[4]
    'v',   'e_oemid',                     #// OEM identifier (for e_oeminfo)
    'v',   'e_oeminfo',                   #// OEM information; e_oemid specific
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'v',   nil,                           #// Reserved words - e_res2[10]
    'V',   'e_lfanew',                    #// File address of new exe header
])
SIZEOF_IMAGE_DOS_HEADER = IMAGE_DOS_HEADER.size
  
IMAGE_OPTIONAL_HEADER32 = BinaryStruct.new([
#    //
#    // Standard fields.
#    //

    'v',    'Magic',
    'c',    'MajorLinkerVersion',
    'c',    'MinorLinkerVersion',
    'V',    'SizeOfCode',
    'V',    'SizeOfInitializedData',
    'V',    'SizeOfUninitializedData',
    'V',    'AddressOfEntryPoint',
    'V',    'BaseOfCode',
    'V',    'BaseOfData',
#
#    //
#    // NT additional fields.
#    //
#
    'V',    'ImageBase',
    'V',    'SectionAlignment',
    'V',    'FileAlignment',
    'v',    'MajorOperatingSystemVersion',
    'v',    'MinorOperatingSystemVersion',
    'v',    'MajorImageVersion',
    'v',    'MinorImageVersion',
    'v',    'MajorSubsystemVersion',
    'v',    'MinorSubsystemVersion',
    'V',    'Win32VersionValue',
    'V',    'SizeOfImage',
    'V',    'SizeOfHeaders',
    'V',    'CheckSum',
    'v',    'Subsystem',
    'v',    'DllCharacteristics',
    'V',    'SizeOfStackReserve',
    'V',    'SizeOfStackCommit',
    'V',    'SizeOfHeapReserve',
    'V',    'SizeOfHeapCommit',
    'V',    'LoaderFlags',
    'V',    'NumberOfRvaAndSizes',
])
SIZEOF_IMAGE_OPTIONAL_HEADER32 = IMAGE_OPTIONAL_HEADER32.size

IMAGE_OPTIONAL_HEADER64 = BinaryStruct.new([
    'v',    'Magic',
    'c',    'MajorLinkerVersion',
    'c',    'MinorLinkerVersion',
    'V',    'SizeOfCode',
    'V',    'SizeOfInitializedData',
    'V',    'SizeOfUninitializedData',
    'V',    'AddressOfEntryPoint',
    'V',    'BaseOfCode',
    'Q',    'ImageBase',
    'V',    'SectionAlignment',
    'V',    'FileAlignment',
    'v',    'MajorOperatingSystemVersion',
    'v',    'MinorOperatingSystemVersion',
    'v',    'MajorImageVersion',
    'v',    'MinorImageVersion',
    'v',    'MajorSubsystemVersion',
    'v',    'MinorSubsystemVersion',
    'V',    'Win32VersionValue',
    'V',    'SizeOfImage',
    'V',    'SizeOfHeaders',
    'V',    'CheckSum',
    'v',    'Subsystem',
    'v',    'DllCharacteristics',
    'Q',    'SizeOfStackReserve',
    'Q',    'SizeOfStackCommit',
    'Q',    'SizeOfHeapReserve',
    'Q',    'SizeOfHeapCommit',
    'V',    'LoaderFlags',
    'V',    'NumberOfRvaAndSizes',
])
SIZEOF_IMAGE_OPTIONAL_HEADER64 = IMAGE_OPTIONAL_HEADER64.size

IMAGE_DATA_DIRECTORY = BinaryStruct.new([
    'V',   :virtualAddress,
    'V',   :size,
])
SIZEOF_IMAGE_DATA_DIRECTORY = IMAGE_DATA_DIRECTORY.size

IMAGE_SECTION_HEADER = BinaryStruct.new([
    'a8',  'Name',
#    union {
#            DWORD   PhysicalAddress;
#            DWORD   VirtualSize;
#    } Misc;
    'V',   :VirtualSize,
    'V',   :virtualAddress,
    'V',   'SizeOfRawData',
    'V',   :PointerToRawData,
    'V',   'PointerToRelocations',
    'V',   'PointerToLinenumbers',
    'v',   'NumberOfRelocations',
    'v',   'NumberOfLinenumbers',
    'V',   'Characteristics',
])
SIZEOF_IMAGE_SECTION_HEADER = IMAGE_SECTION_HEADER.size

IMAGE_IMPORT_DESCRIPTOR = BinaryStruct.new([
#    union {
#        DWORD   Characteristics;           #// 0 for terminating null import descriptor
#        DWORD   OriginalFirstThunk;        #// RVA to original unbound IAT (PIMAGE_THUNK_DATA)
#    };
    'V',  'Characteristics',
    'V',  'TimeDateStamp',                  #// 0 if not bound,
    #// -1 if bound, and real date\time stamp
    #//     in IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT (new BIND)
    #// O.W. date/time stamp of DLL bound to (Old BIND)

    'V',   'ForwarderChain',                #// -1 if no forwarders
    'V',   'Name',
    'V',   'FirstThunk',                    #// RVA to IAT (if bound this IAT has actual addresses)
])
SIZEOF_IMAGE_IMPORT_DESCRIPTOR = IMAGE_IMPORT_DESCRIPTOR.size

# General resource definitions.
IMAGE_RESOURCE_DIRECTORY = BinaryStruct.new([
    'L',	:characteristics,
    'L',	:timeDateStamp,
    'S',	:majorVersion,
    'S',	:minorVersion,
    'S',	:numberOfNamedEntries,							# Number of named entries that follow this struc (first).
    'S',	:numberOfIdEntries,								# Number of ID entries that follow this struc (second).
])
SIZEOF_IMAGE_RESOURCE_DIRECTORY = IMAGE_RESOURCE_DIRECTORY.size

IMAGE_RESOURCE_DIRECTORY_ENTRY = BinaryStruct.new([
    'L',	:name,															# Name or ID. If bit 31 = 0 then ID. If bit 31 = 1, then
    # bits 0-30 are an offset (from start of rsrc) to IMAGE_RESOURCE_DIR_STRING_U.
    'L',	:offsetToData,											# Ptr to dir or data. If bit 31 = 0, then ptr to
    # IMAGE_REDSOURCE_DATA_ENTRY. If bit 31 = 1, then bits 0-30 are ptr to IMAGE_RESOURCE_DIRECTORY.
])
SIZEOF_IMAGE_RESOURCE_DIRECTORY_ENTRY = IMAGE_RESOURCE_DIRECTORY_ENTRY.size

# NOTE: Skipping string resource name because it is self-referencing:
#typedef struct _IMAGE_RESOURCE_DIR_STRING_U {
#    WORD    Length;
#    WCHAR   NameString[ 1 ];
#} IMAGE_RESOURCE_DIR_STRING_U, *PIMAGE_RESOURCE_DIR_STRING_U;
# The member NameString is Length characters long, so the final size of the structure is unknown.
# This is just handled without BinaryStruct.

IMAGE_RESOURCE_DATA_ENTRY = BinaryStruct.new([
    'L',	:offsetToData,											# This offset is an RVA.
    'L',	:size,															# Size in bytes.
    'L',	:codePage,													# Code page (for strings).
    'L',	:reserved1,
])
SIZEOF_IMAGE_RESOURCE_DATA_ENTRY = IMAGE_RESOURCE_DATA_ENTRY.size

# Icon specific resource definitions.
GRPICONDIR = BinaryStruct.new([
    'S',	:idReserved1,
    'S',	:idType,														# 1 for icons.
    'S',	:idCount,                           # Count of images.
    'a*',	:data,															# Array of GRPICONDIRENTRY.
])
SIZEOF_GRPICONDIR = GRPICONDIR.size           # TODO: BinaryStruct.sizeof ignores the *

GRPICONDIRENTRY = BinaryStruct.new([
    'C',	:bWidth,														# Pixel width of image.
    'C',	:bHeight,                           # Pixel height of image.
    'C',	:bColorCount,                       # Colors in image (0 if >= 8bpp).
    'C',	:bReserved1,
    'S',	:wPlanes,                           # Color planes.
    'S',	:wBitCount,                         # Bits per pixel.
    'L',	:dwBytesInRes,											# Bytes in this resource.
    'S',	:nID,                               # Resource ID.
    # NOTE: In an .ico file, last member is 'L', 'dwImageOffset', an offset
    # from the beginning of the file to the BITMAPINFOHEADER of the icon data.
])
SIZEOF_GRPICONDIRENTRY = GRPICONDIRENTRY.size

# Messagetable specific resource definitions.
MESSAGE_RESOURCE_DATA = BinaryStruct.new([
    'L',	:numberOfBlocks,										# Length of data array.
    'a*',	:data,															# Array of MESSAGE_RESOURCE_BLOCK.
])
SIZEOF_MESSAGE_RESOURCE_DATA = MESSAGE_RESOURCE_DATA.size    # TODO: BinaryStruct.sizeof ignores the *

MESSAGE_RESOURCE_BLOCK = BinaryStruct.new([
    'L',	:loId,
    'L',	:hiId,
    'L',	:offsetToEntries,									# RVA?
])
SIZEOF_MESSAGE_RESOURCE_BLOCK = MESSAGE_RESOURCE_BLOCK.size
SIZEOF_MRB = 12

MESSAGE_RESOURCE_ENTRY = BinaryStruct.new([
    'S',	:length,														# String length.
    'S',	:flags,														# Encoding (see below).
])
SIZEOF_MRE = 4
SIZEOF_MESSAGE_RESOURCE_ENTRY = MESSAGE_RESOURCE_ENTRY.size
# Text follows here.

MESSAGE_RESOURCE_ANSI    	= 0x0000					# If set text is ANSI.
MESSAGE_RESOURCE_UNICODE	= 0x0001					# If set text is UNICODE.

VS_VERSION_INFO_HEADER = BinaryStruct.new([
  'a32', 'sig',
  's',   nil,
  's',   nil,
  's',   nil,
  's',   nil,
  's',   nil,
  'S',   'fminor',
  'S',   'fmajor',
  'S',   'fbuild',
  'S',   'frev',
  'S',   'pminor',
  'S',   'pmajor',
  'S',   'pbuild',
  'S',   'prev',
])
SIZEOF_VS_VERSION_INFO_HEADER = VS_VERSION_INFO_HEADER.size

STRING_INFO_HEADER = BinaryStruct.new([
  'a30', 'sig',
  'V',   'data_length',
  's',   'type',
  'a8',  'lang',
  'a8',  'code_page',
])
SIZEOF_STRING_INFO_HEADER = STRING_INFO_HEADER.size

VERSION_STRING_HEADER = BinaryStruct.new([
  's', 'zero',
  's', 'slen',
  's', 'vlen',
  's', 'type',
])
SIZEOF_VERSION_STRING_HEADER = VERSION_STRING_HEADER.size

STRINGFILEINFO  = "S\0t\0r\0i\0n\0g\0F\0i\0l\0e\0I\0n\0f\0o\0\0\0"
VS_VERSION_INFO = "V\0S\0_\0V\0E\0R\0S\0I\0O\0N\0_\0I\0N\0F\0O\0\0\0"

IMAGE_SIZEOF_NT_OPTIONAL32_HEADER = 224
IMAGE_SIZEOF_NT_OPTIONAL64_HEADER = 240

IMAGE_NT_OPTIONAL_HDR32_MAGIC     = 0x10b
IMAGE_NT_OPTIONAL_HDR64_MAGIC     = 0x20b
end

###########################################################
# Only run if we are calling this script directly
if __FILE__ == $0 then
  st = Time.now
  puts "Running script [#{__FILE__}]"
  fileName = "D:/temp/icons/PSPad.exe"
  fileName = "D:/temp/icons/EventMsg2.dll"
  peHdr = PEheader.new(fileName)
  puts "Imports:[#{peHdr.imports.length}] - #{peHdr.imports.join(", ")}"
  puts "VerionsInfo: #{peHdr.versioninfo.inspect}"
  puts "Icon Count: [#{peHdr.icons.length}]"
  # Dump icons to d:\temp\icons\icon{n}.ico
  peHdr.icons.each_with_index {|icon, ico| File.open("d:/temp/icons/icon#{ico}.ico", "wb") {|f| f.write(icon)}}

  puts "MessageTable Count: [#{peHdr.messagetables.length}]"
  peHdr.messagetables.each {|m| puts m}
  
  puts "completed script [#{__FILE__}]  [#{Time.now-st}]"
end
