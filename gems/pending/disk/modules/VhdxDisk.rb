# encoding: US-ASCII

require 'util/miq-unicode'
require 'binary_struct'
require 'disk/MiqDisk'
require 'memory_buffer'
require 'disk/modules/MiqLargeFile'
require 'disk/modules/vhdx_bat_entry'

module VhdxDisk
  # NOTE: All values are stored in network byte order.

  VHDX_FILE_IDENTIFIER = BinaryStruct.new([
    'Q<',   'signature',        # Always 'vhdxfile'.
    'A256', 'creator',          # Parser that created the vhdx.
  ])
  SIZEOF_VHDX_FILE_IDENTIFIER        = VHDX_FILE_IDENTIFIER.size
  VHDX_FILE_IDENTIFIER_SIGNATURE     = 0x656C696678646876

  VHDX_HEADER                        = BinaryStruct.new([
    'I<',    'signature',       # Always 'head'.
    'I<',    'checksum',        # cfc-32c hash over entire 4 KB structure
    'Q<',    'sequence_number', #
    'A16',  'file_write_guid',  # Identifies the file's contents
    'A16',  'data_write_guid',  # Identifies the user visible data
    'A16',  'log_guid',         # Determines validity of log entries
    'S<',    'log_version',     # The version of the log format.
    'S<',    'version',         # The version of the VHDX format.
    'I<',    'log_length',      # Length of the log
    'I<',    'log_offset',      # Byte offset of the log
    'A4016', 'reserved',        # reserved
  ])
  SIZEOF_VHDX_HEADER                 = VHDX_HEADER.size
  VHDX_HEADER_OFFSET                 = 64 * 1024
  VHDX_HEADER_SIGNATURE              = 0x64616568
  VHDX_HEADER2_OFFSET                = 2 * 64 * 1024

  VHDX_REGION_TABLE_HEADER           = BinaryStruct.new([
    'I<',  'signature',         # Always 'regi'.
    'I<',  'checksum',          # cfc-32c hash over entire 4 KB structure
    'I<',  'entry_count',       # Number of Region Table entries
    'I<',  'reserved',          # reserved
  ])
  SIZEOF_VHDX_REGION_TABLE_HEADER    = VHDX_REGION_TABLE_HEADER.size
  VHDX_REGION_TABLE_HEADER_OFFSET    = 64 * 1024
  VHDX_REGION_TABLE_HEADER_SIGNATURE = 0x69676572

  VHDX_REGION_TABLE_ENTRY            = BinaryStruct.new([
    'A16',  'guid',             # GUID must be unique within the table
    'Q<',   'file_offset',      # offset of the Region Table entry (1MB multiples)
    'I<',   'length',           # Byte length of the object (1MB multiples)
    'I<',   'required',         # 1st bit is required, 31 remaining bits reserved
  ])
  SIZEOF_VHDX_REGION_TABLE_ENTRY     = VHDX_REGION_TABLE_ENTRY.size
  REGION_TABLE_BAT_GUID              = 0x2DC27766F62342009D64115E9BFD4A08
  REGION_TABLE_METADATA_GUID         = 0x8B7CA20647904B9AB8FE575F050F886E

  VHDX_BAT_STATE_ENTRY               = BinaryStruct.new([
    'B8',    'state',             # least significant three bits only
    'B8',    'reserved',
    'B48',   'file_offset_mb'     # the offset within the file in units of 1 MB
  ])
  VHDX_BAT_ENTRY = BinaryStruct.new([
    'Q<',    'file_offset_mb',    # most significant 44 bits only
  ])
  SIZEOF_VHDX_BAT_ENTRY              = VHDX_BAT_ENTRY.size
  BAT_OFFSET_MASK                    = 0x00000FFFFFFFFFFF
  BAT_OFFSET_SHIFT                   = 20
  BAT_OFFSET_UNITS                   = 1024 * 1024 # units for fill_offset_mb field

  PAYLOAD_BLOCK_NOT_PRESENT          = 0
  PAYLOAD_BLOCK_UNDEFINED            = 1
  PAYLOAD_BLOCK_ZERO                 = 2
  PAYLOAD_BLOCK_UNMAPPED             = 3
  PAYLOAD_BLOCK_FULLY_PRESENT        = 6
  PAYLOAD_BLOCK_PARTIALLY_PRESENT    = 7

  SB_BLOCK_NOT_PRESENT               = 0
  SB_BLOCK_PRESENT                   = 6
  SECTOR_BITMAP_BLOCKSIZE            = 1024 * 1024

  VHDX_METADATA_TABLE_HEADER         = BinaryStruct.new([
    'Q<',   'signature',        # Always 'metadata'
    'S<',   'reserved',         #
    'S<',   'entry_count',      # number of entries in the table
    'I5',   'reserved2',        #
  ])
  SIZEOF_VHDX_METADATA_TABLE_HEADER    = VHDX_METADATA_TABLE_HEADER.size
  VHDX_METADATA_TABLE_HEADER_SIGNATURE = 0x617461646174656D

  VHDX_METADATA_TABLE_ENTRY            = BinaryStruct.new([
    'A16', 'item_id',           # item_id and isuser pair must be unique within the table
    'I<',   'offset',           # offset relative to beginning of the metadata region >= 64KB
    'I<',   'length',           # < = 1MB
    'b32',  'bit_fields',
    # 'B1', 'is_user',          # system or user metadata
    # 'B1', 'is_virtual_disk',  # file or virtual disk metadata
    # 'B1', 'is_required',      #
    # 'B29', 'reserved',
    'I<',   'reserved2'
  ])
  SIZEOF_VHDX_METADATA_TABLE_ENTRY   = VHDX_METADATA_TABLE_ENTRY.size

  FILE_PARAMETERS_GUID               = 0xCAA16737FA364D43B3B633F0AA44E76B
  VIRTUAL_DISK_SIZE_GUID             = 0x2FA54224CD1B4876B2115DBED83BF4B8
  PAGE_83_DATA_GUID                  = 0xBECA12ABB2E6452393EFC309E000C746
  LOGICAL_SECTOR_SIZE_GUID           = 0x8141BF1DA96F4709BA47F233A8FAAB5F
  PHYSICAL_SECTOR_SIZE_GUID          = 0xCDA348C7445D44719CC9E9885251C556
  PARENT_LOCATOR_GUID                = 0xA8D35F2DB30B454DABF7D3D84834AB0C

  METADATA_OPS                       = {
    FILE_PARAMETERS_GUID      => :file_parameters,
    VIRTUAL_DISK_SIZE_GUID    => :virtual_disk_size,
    PAGE_83_DATA_GUID         => :page_83_data,
    LOGICAL_SECTOR_SIZE_GUID  => :logical_sector_size,
    PHYSICAL_SECTOR_SIZE_GUID => :physical_sector_size,
    PARENT_LOCATOR_GUID       => :parent_locator_header
  }

  ALLOCATION_STATUS = {
    PAYLOAD_BLOCK_NOT_PRESENT       => PAYLOAD_BLOCK_NOT_PRESENT,
    PAYLOAD_BLOCK_UNDEFINED         => nil,
    PAYLOAD_BLOCK_ZERO              => nil,
    PAYLOAD_BLOCK_UNMAPPED          => nil,
    PAYLOAD_BLOCK_FULLY_PRESENT     => PAYLOAD_BLOCK_FULLY_PRESENT,
    PAYLOAD_BLOCK_PARTIALLY_PRESENT => PAYLOAD_BLOCK_PARTIALLY_PRESENT
  }

  VHDX_FILE_PARAMETERS = BinaryStruct.new([
    'I<',  'block_size', # size of payload block in bytes between 1MB & 256MB
    'b32', 'bit_fields',
    # 'B1',  'leave_blocks_allocated',
    # 'B1',  'has_parent',
    # 'B30', 'reserved',
  ])
  SIZEOF_VHDX_FILE_PARAMETERS        = VHDX_FILE_PARAMETERS.size

  VHDX_VIRTUAL_DISK_SIZE             = BinaryStruct.new([
    'Q<', 'virtual_disk_size' # size in bytes.  must be a multiple of logical sector size
  ])
  SIZEOF_VHDX_VIRTUAL_DISK_SIZE = VHDX_VIRTUAL_DISK_SIZE.size

  VHDX_LOGICAL_SECTOR_SIZE = BinaryStruct.new([
    'I<', 'logical_sector_size' # size in bytes.  must be 512 or 4096
  ])
  SIZEOF_VHDX_LOGICAL_SECTOR_SIZE = VHDX_LOGICAL_SECTOR_SIZE.size

  VHDX_PHYSICAL_SECTOR_SIZE = BinaryStruct.new([
    'I<', 'physical_sector_size' # size in bytes.  must be 512 or 4096
  ])
  SIZEOF_VHDX_PHYSICAL_SECTOR_SIZE   = VHDX_PHYSICAL_SECTOR_SIZE.size

  VHDX_PAGE_83_DATA                  = BinaryStruct.new([
    'A16', 'page_83_data' # unique guid
  ])
  SIZEOF_VHDX_PAGE_83_DATA           = VHDX_PAGE_83_DATA.size

  VHDX_PARENT_LOCATOR_HEADER         = BinaryStruct.new([
    'A16', 'locator_type',      # guid with type of the parent virtual disk
    'S<',   'reserved',
    'S<',   'key_value_count',  # number of key-value pairs for the parent locator
  ])
  SIZEOF_VHDX_PARENT_LOCATOR_HEADER  = VHDX_PARENT_LOCATOR_HEADER.size
  VHDX_PARENT_LOCATOR_TYPE_GUID      = 0xB04AEFB7D19E4A81B78925B8E9445913

  VHDX_PARENT_LOCATOR_ENTRY          = BinaryStruct.new([
    'I<',   'key_offset',       # offset within the metadata item of key
    'I<',   'value_offset',     # offset within the metadata item of value
    'S<',   'key_length',       # length of the entry's key
    'S<',   'value_length',     # length of the entry's value
  ])
  SIZEOF_VHDX_PARENT_LOCATOR_ENTRY = VHDX_PARENT_LOCATOR_ENTRY.size

  attr_reader :file_identifier_signature, :vhdx_header_signature, :dInfo
  def d_init
    @diskType             = "Vhdx"
    @blockSize            = 0
    @virtual_disk_size    = 0
    @logical_sector_size  = 0
    @physical_sector_size = 0
    @payload_block_size   = 0
    @has_parent           = nil
    @parent_locator       = nil
    @file_name            = dInfo.fileName
    @hyperv_connection    = nil
    @vhdx_file            = connection_to_file(dInfo)
    @converter            = Encoding::Converter.new("UTF-16LE", "UTF-8")
    header_section
  end

  def connection_to_file(dInfo)
    if dInfo.mountMode.nil? || dInfo.mountMode == "r"
      dInfo.mountMode     = "r"
      file_mode           = "r"
    elsif dInfo.mountMode == "rw"
      file_mode           = "r+"
    else
      raise "Unrecognized mountMode: #{dInfo.mountMode}"
    end
    if dInfo.hyperv_connection
      @vhdx_file = connect_to_hyperv(dInfo)
    else
      @vhdx_file = MiqLargeFile.open(@file_name, file_mode)
    end
    @vhdx_file
  end

  def d_read(pos, len)
    raise "VhdxDisk.d_read Invalid len #{len} #{@has_parent ? "Checkpoint Disk" : "Parent Disk"}\n #{caller}" if len < 0
    $log.debug "VhdxDisk.d_read(#{pos}, #{len})"
    buf = ""
    return buf if len == 0
    block_start, sector_start, byte_offset_start = block_pos(pos)
    block_end,   sector_end,   _byte_offset_end  = block_pos(pos + len - 1)
    byte_offset = 0
    this_len    = @blockSize
    (block_start..block_end).each do |block_number|
      real_sector_start = (block_number == block_start) ? sector_start : 0
      real_sector_end   = (block_number == block_end) ? sector_end : @sectors_per_block - 1
      allocation_status = get_allocation_status(block_number)
      bat_offset        = bat_offset(block_number)
      (real_sector_start..real_sector_end).each do |sector_number|
        if (block_start == block_end) && (sector_start == sector_end)
          byte_offset = byte_offset_start
          this_len    = len
        elsif (block_number == block_start) && (sector_number == sector_start)
          byte_offset = byte_offset_start
          this_len    = @blockSize - byte_offset
        elsif (block_number == block_end) && (sector_number == sector_end)
          byte_offset = 0
          this_len    = len - buf.length
          raise "Internal Error: Calculated read more than sector: #{this_len}" if this_len > @blockSize
        else
          byte_offset = 0
          this_len    = @blockSize
        end
        if allocation_status.nil? || allocation_status == PAYLOAD_BLOCK_NOT_PRESENT
          buf << read_unallocated_buf(pos, this_len, buf, allocation_status == PAYLOAD_BLOCK_NOT_PRESENT)
        else
          if allocation_status == PAYLOAD_BLOCK_PARTIALLY_PRESENT
            sector_status = get_sector_allocation_status(block_number, sector_number)
            $log.debug "PAYLOAD_BLOCK_PARTIALLY_PRESENT & sector_status #{sector_status} for sector #{sector_number}"
            if sector_status == false
              buf << read_unallocated_buf(pos, this_len, buf, true)
              next
            end
          end
          byte_offset += sector_number * @logical_sector_size
          @vhdx_file.seek(bat_offset + byte_offset, IO::SEEK_SET)
          buf << @vhdx_file.read(this_len)
        end
      end
    end
    buf
  end

  def d_write(pos, buf, len)
    @vhdx_file.seek(pos, IO::SEEK_SET)
    @vhdx_file.write(buf, len)
  end

  def d_close
    @vhdx_file.close
  end

  # Disk size in sectors.
  def d_size
    @virtual_disk_size / @logical_sector_size
  end

  def getBase
    self
  end

  private

  def read_unallocated_buf(pos, len, buf, status)
    if status == true && @has_parent == true
      return @parent.d_read(pos + buf.length, len)
    else
      return MemoryBuffer.create(len)
    end
  end

  def header_section
    @file_identifier       = file_identifier
    @vhdx_header           = header(1)
    unless valid_header_signature?
      $log.info "Invalid VHDX Header Signature #{@vhdx_header_signature}"
      @vhdx_header = header(2)
    end
    raise "Invalid VHDX Header Signature #{@vhdx_header_signature}" unless valid_header_signature?
    @region_table_header = region_table(1)
    unless valid_region_table_header?
      $log.info "Invalid Region Table Header Signature #{@region_table_header_signature}"
      @region_table_header = header(2)
    end
    raise "Invalid Region Table Header Signature #{@region_table_header_signature}" unless valid_region_table_header?
  end

  def file_identifier
    @vhdx_file.seek(0, IO::SEEK_SET)
    file_identifier            = VHDX_FILE_IDENTIFIER.decode(@vhdx_file.read(SIZEOF_VHDX_FILE_IDENTIFIER))
    @file_identifier_signature = file_identifier['signature']
    raise "Invalid VHDX File Identifier Signature #{@file_identifier_signature}" unless valid_file_identifier_signature?
    file_identifier
  end

  def valid_file_identifier_signature?
    @file_identifier_signature == VHDX_FILE_IDENTIFIER_SIGNATURE
  end

  def header(header_number)
    @vhdx_file.seek(header_number * VHDX_HEADER_OFFSET, IO::SEEK_SET)
    vhdx_header            = VHDX_HEADER.decode(@vhdx_file.read(SIZEOF_VHDX_HEADER))
    @vhdx_header_signature = vhdx_header['signature']
    vhdx_header
  end

  def valid_header_signature?
    @vhdx_header_signature == VHDX_HEADER_SIGNATURE
  end

  def region_table(table_number)
    table_offset = 2 * VHDX_HEADER_OFFSET + table_number * VHDX_REGION_TABLE_HEADER_OFFSET
    header       = region_table_header(table_offset)
    return if header.nil?
    (1..header['entry_count']).each do |count|
      process_region_table_entry(table_offset, count)
    end
    process_metadata_table_header
    process_bat
  end

  def region_table_header(table_offset)
    @vhdx_file.seek(table_offset, IO::SEEK_SET)
    region_table_header = VHDX_REGION_TABLE_HEADER.decode(@vhdx_file.read(SIZEOF_VHDX_REGION_TABLE_HEADER))
    @region_table_header_signature = region_table_header['signature']
    unless valid_region_table_header?
      $log.info "Invalid Region Table Header #{@region_table_header_signature}"
      return nil
    end
    unless region_table_header['entry_count'] > 0
      $log.warn "Invalid Region Table Entry Count #{region_table_header['entry_count']}"
      return nil
    end
    region_table_header
  end

  def valid_region_table_header?
    @region_table_header_signature == VHDX_REGION_TABLE_HEADER_SIGNATURE
  end

  def process_region_table_entry(table_offset, count)
    table_entry        = region_table_entry(table_offset, count)
    region_table_guid  = table_entry['guid']
    file_offset        = table_entry['file_offset']
    length             = table_entry['length']
    if guid_match?(region_table_guid, REGION_TABLE_BAT_GUID)
      @bat_offset      = file_offset
      @bat_length      = length
    elsif guid_match?(region_table_guid, REGION_TABLE_METADATA_GUID)
      @metadata_offset = file_offset
      @metadata_length = length
    else
      raise "Invalid Region Table GUID Type #{region_table_guid}"
    end
  end

  def region_table_entry(table_offset, count)
    offset_to_entry = table_offset + SIZEOF_VHDX_REGION_TABLE_HEADER + (count - 1) * SIZEOF_VHDX_REGION_TABLE_ENTRY
    @vhdx_file.seek(offset_to_entry, IO::SEEK_SET)
    VHDX_REGION_TABLE_ENTRY.decode(@vhdx_file.read(SIZEOF_VHDX_REGION_TABLE_ENTRY))
  end

  def process_bat
    @vhdx_file.seek(@bat_offset, IO::SEEK_SET)
    @bat = []
    1.step(@total_bat_entries, 1) do |block_num|
      encoded_bat_entry    = @vhdx_file.read(SIZEOF_VHDX_BAT_ENTRY)

      next_bat_state_entry = VHDX_BAT_STATE_ENTRY.decode(encoded_bat_entry)
      state                = next_bat_state_entry['state'][5..7].to_i(2) # 3 least significant bits

      next_bat_entry       = VHDX_BAT_ENTRY.decode(encoded_bat_entry)
      file_offset_mb       = (next_bat_entry['file_offset_mb'] >> BAT_OFFSET_SHIFT) & BAT_OFFSET_MASK

      entry = VhdxBatEntry.new(block_num, state, file_offset_mb)
      @bat << entry
    end
  end

  def compute_bat_offset(offset_bits)
    (offset_bits & BAT_OFFSET_MASK) >> BAT_OFFSET_SHIFT
  end

  def process_metadata_table_header
    @vhdx_file.seek(@metadata_offset, IO::SEEK_SET)
    metadata_table_header = VHDX_METADATA_TABLE_HEADER.decode(@vhdx_file.read(SIZEOF_VHDX_METADATA_TABLE_HEADER))
    signature             = metadata_table_header['signature']
    count                 = metadata_table_header['entry_count']
    raise "Invalid Metadata Header Signature #{signature}" unless signature == VHDX_METADATA_TABLE_HEADER_SIGNATURE
    raise "Invalid Metadata Header Entry Count #{count}" unless count > 0
    (1..count).each do |i|
      process_metadata_table_entry(i)
    end
    raise "Invalid or Missing Metadata Table Entries" unless valid_metadata_table?
    post_process_metadata
  end

  def post_process_metadata
    @chunk_ratio                = (2**23 * @logical_sector_size) / @payload_block_size
    @data_blocks_count          = (@virtual_disk_size / @payload_block_size).ceil
    @sector_bitmap_blocks_count = (@data_blocks_count / @chunk_ratio).ceil
    @sectors_per_block          = @payload_block_size / @logical_sector_size
    if @has_parent
      @total_bat_entries = @sector_bitmap_blocks_count * (@chunk_ratio + 1)
    else
      @total_bat_entries = @data_blocks_count + ((@data_blocks_count - 1) / @chunk_ratio).floor
    end
  end

  def process_metadata_table_entry(entry_number)
    entry_offset = @metadata_offset + SIZEOF_VHDX_METADATA_TABLE_HEADER +
                   (entry_number - 1) * SIZEOF_VHDX_METADATA_TABLE_ENTRY
    @vhdx_file.seek(entry_offset, IO::SEEK_SET)
    metadata_table_entry = VHDX_METADATA_TABLE_ENTRY.decode(@vhdx_file.read(SIZEOF_VHDX_METADATA_TABLE_ENTRY))
    guid             = metadata_table_entry['item_id']
    offset           = @metadata_offset + metadata_table_entry['offset']
    length           = metadata_table_entry['length']
    bits             = metadata_table_entry['bit_fields']
    @is_user         = bits[0].to_i(2)
    @is_virtual_disk = bits[1].to_i(2)
    @is_required     = bits[2].to_i(2)
    if length == 0
      raise "Invalid Metadata Table Entry - Length Zero and Offset is #{offset}" if offset != 0
      $log.debug "Metadata Table Entry Present but Empty"
      return
    end
    @vhdx_file.seek(offset, IO::SEEK_SET)
    guid_found = nil
    METADATA_OPS.each do |meta_guid, op|
      next unless guid_match?(guid, meta_guid)
      method(op).call(offset)
      guid_found = guid
      break
    end
    raise "Invalid Metadata Table Entry GUID #{guid}" unless guid_found
  end

  def file_parameters(_offset)
    file_parameters_entry   = VHDX_FILE_PARAMETERS.decode(@vhdx_file.read(SIZEOF_VHDX_FILE_PARAMETERS))
    @payload_block_size     = file_parameters_entry['block_size']
    bits                    = file_parameters_entry['bit_fields']
    @leave_blocks_allocated = bits[0].to_i(2) == 1
    @has_parent             = bits[1].to_i(2) == 1
    $log.debug "Payload Block Size #{@payload_block_size} Leave Blocks Allocated #{@leave_blocks_allocated}"
    $log.debug "Has Parent #{@has_parent}"
  end

  def virtual_disk_size(_offset)
    virtual_disk_metadata = VHDX_VIRTUAL_DISK_SIZE.decode(@vhdx_file.read(SIZEOF_VHDX_VIRTUAL_DISK_SIZE))
    @virtual_disk_size    = virtual_disk_metadata['virtual_disk_size']
    $log.debug "Virtual Disk Size #{@virtual_disk_size}"
  end

  def page_83_data(_offset)
    page_83_metadata = VHDX_PAGE_83_DATA.decode(@vhdx_file.read(SIZEOF_VHDX_PAGE_83_DATA))
    @page_83_data    = page_83_metadata['page_83_data']
    $log.debug "Page 83 Data #{@page_83_data}"
  end

  def logical_sector_size(_offset)
    logical_sector_metadata = VHDX_LOGICAL_SECTOR_SIZE.decode(@vhdx_file.read(SIZEOF_VHDX_LOGICAL_SECTOR_SIZE))
    @logical_sector_size    = logical_sector_metadata['logical_sector_size']
    @blockSize              = @logical_sector_size
    $log.debug "Logical Sector Size (blockSize) #{@logical_sector_size}"
  end

  def physical_sector_size(_offset)
    physical_sector_metadata = VHDX_PHYSICAL_SECTOR_SIZE.decode(@vhdx_file.read(SIZEOF_VHDX_PHYSICAL_SECTOR_SIZE))
    @physical_sector_size    = physical_sector_metadata['physical_sector_size']
    $log.debug "Physical Sector Size #{@physical_sector_size}"
  end

  def parent_locator_header(offset)
    raise "Inconsistent filesystem - \'Has_Parent\' Flag unset but Parent Locator Info Present" if @has_parent == false
    @parent_locator         = VHDX_PARENT_LOCATOR_HEADER.decode(@vhdx_file.read(SIZEOF_VHDX_PARENT_LOCATOR_HEADER))
    @parent_locator_entries = {}
    key_value_count         = @parent_locator['key_value_count']
    guid                    = @parent_locator['locator_type']
    raise "Invalid Parent Locator Type Guid #{guid}" unless guid_match?(guid, VHDX_PARENT_LOCATOR_TYPE_GUID)
    return if key_value_count == 0
    (1..key_value_count).each do |i|
      @vhdx_file.seek(offset + SIZEOF_VHDX_PARENT_LOCATOR_HEADER +
                     (i - 1) * SIZEOF_VHDX_PARENT_LOCATOR_ENTRY, IO::SEEK_SET)
      process_parent_locator_entry(offset)
    end
    keys = @parent_locator_entries.keys
    $log.warn "Missing \"parent_linkage\" Parent Locator Entry" if keys.index("parent_linkage").nil?
    parent_locators_to_path(keys)
  end

  def parent_locators_to_path(keys)
    if keys.index("absolute_win32_path")
      parent_path = strip_path_prefix(@parent_locator_entries["absolute_win32_path"])
    elsif keys.index("relative_path")
      parent_path = File.dirname(@file_name) + '/' + @parent_locator_entries["relative_path"]
    elsif keys.index("volume_path")
      # TODO: Test Volume Path Parent Locator
      parent_path = strip_path_prefix(@parent_locator_entries["volume_path"])
    else
      raise "Missing Parent Locator entries \"relative_path\", \"volume_path\", and \"absolute_win32_path\""
    end
    @parent = parent_disk(parent_path)
  end

  def parent_disk(path)
    @parent_ostruct                   = OpenStruct.new
    @parent_ostruct.fileName          = path
    @parent_ostruct.driveType         = dInfo.driveType
    @parent_ostruct.hyperv_connection = @hyperv_connection if @hyperv_connection
    parent                            = MiqDisk.getDisk(@parent_ostruct)
    raise "Unable to access parent disk #{path}" if parent.nil?
    $log.debug "Got #{path} as Parent disk of #{@file_name}"
    parent
  end

  def strip_path_prefix(path)
    path[0, 4] == "\\\\?\\" ? path[4..-1] : path
  end

  def process_parent_locator_entry(offset)
    entry = VHDX_PARENT_LOCATOR_ENTRY.decode(@vhdx_file.read(SIZEOF_VHDX_PARENT_LOCATOR_ENTRY))
    @vhdx_file.seek(offset + entry['key_offset'], IO::SEEK_SET)
    key = @converter.convert(@vhdx_file.read(entry['key_length'])).gsub(/\"/, '')
    @vhdx_file.seek(offset + entry['value_offset'], IO::SEEK_SET)
    value = @converter.convert(@vhdx_file.read(entry['value_length'])).gsub(/\"/, '')
    @parent_locator_entries[key] = value
  end

  def valid_metadata_table?
    if @virtual_disk_size > 0 && @payload_block_size > 0 && @logical_sector_size > 0 && @physical_sector_size > 0
      return true
    end
    $log.warn "Disk Size #{@virtual_disk_size}"
    $log.warn "Block Size #{@blockSize}"
    $log.warn "Logical Sector Size #{@logical_sector_size}"
    $log.warn "Physical Sector Size #{physical_sector_size}"
    false
  end

  def guid_match?(input, guid)
    new_guid = ""
    input.unpack("I<S<S<C8").each do |x|
      if x < 16
        new_guid += "0#{x.to_s(16)}"
      else
        new_guid += x.to_s(16)
      end
    end
    new_guid == guid.to_s(16)
  end

  def block_pos(pos)
    raw_sector, byte_offset       = pos.divmod(@blockSize)
    block_number, sector_in_block = raw_sector.divmod(@sectors_per_block)
    return block_number, sector_in_block, byte_offset
  end

  def get_allocation_status(block_number)
    allocation_status = bat_status(block_number)
    if allocation_status == PAYLOAD_BLOCK_PARTIALLY_PRESENT
      raise "Invalid status PAYLOAD_BLOCK_PARTIALLY_PRESENT for BAT block number #{block_number}" unless @has_parent
    end
    ALLOCATION_STATUS[allocation_status]
  end

  def get_sector_allocation_status(block_number, sector_number)
    sector_bitmap_status = bitmap_status(block_number)
    raise "Invalid Sector Bitmap Status #{sector_bitmap_status}" unless sector_bitmap_status == SB_BLOCK_PRESENT
    sector_bitmap_offset    = bitmap_offset(block_number)
    sector_byte, bit_offset = sector_number.divmod(8)
    @vhdx_file.seek(sector_bitmap_offset + sector_byte, IO::SEEK_SET)
    sector_mask   = 0x80 >> bit_offset
    sector_bitmap = @vhdx_file.read(1).unpack("C")[0]
    sector_bitmap & sector_mask == sector_mask
  end

  def bat_status(block_number)
    bat_entry = @bat[bat_entry_number(block_number)]
    bat_entry.state
  end

  def bat_offset(block_number)
    bat_entry = @bat[bat_entry_number(block_number)]
    bat_entry.offset * BAT_OFFSET_UNITS
  end

  def bat_entry_number(block_number)
    block_number + block_number / @chunk_ratio
  end

  def bitmap_status(block_number)
    bat_entry = @bat[bitmap_entry_number(block_number)]
    bat_entry.state
  end

  def bitmap_offset(block_number)
    bat_entry = @bat[bitmap_entry_number(block_number)]
    bat_entry.offset * BAT_OFFSET_UNITS
  end

  def bitmap_entry_number(block_number)
    (block_number / @chunk_ratio) * (@chunk_ratio + 1) + @chunk_ratio
  end

  def connect_to_hyperv(disk_info)
    connection  = @hyperv_connection = disk_info.hyperv_connection
    @network    = disk_info.driveType == "Network"
    hyperv_disk = MiqHyperVDisk.new(connection[:host],
                                    connection[:user],
                                    connection[:password],
                                    connection[:port],
                                    @network)
    hyperv_disk.open(@file_name)
    hyperv_disk
  end
end
