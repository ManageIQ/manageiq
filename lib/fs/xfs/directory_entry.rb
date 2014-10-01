$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module XFS
  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.
  #
  # Active entry in a data block.
  # Aligned to 8 bytes.  A variable length name field follows the length.
  # After the name there is a 2 byte tag field.
  # For dir3 structures, there is a 1 byte file type field between the name
  # and the tag.  It is packed hard against the end of the name so any padding
  # for rounding is between the file type and the tag.
  DIRECTORY2_DATA_ENTRY = BinaryStruct.new([
    'Q>',  'inumber',   # inode number
    'C',   'name_len',  # name length
  ])
  SIZEOF_DIRECTORY2_DATA_ENTRY = DIRECTORY2_DATA_ENTRY.size

  DIRECTORY2_DATA_TAG = BinaryStruct.new([
    'S>',  'tag',       # tag
  ])
  SIZEOF_DIRECTORY2_DATA_TAG = DIRECTORY2_DATA_TAG.size

  DIRECTORY2_UNUSED_ENTRY = BinaryStruct.new([
    'S>',  'freetag',   # 0xFFFF if unused
    'S>',  'length',    # length of this free entry
  ])
  SIZEOF_DIRECTORY2_UNUSED_ENTRY = DIRECTORY2_UNUSED_ENTRY.size

  class DirectoryEntry
    XFS_DIR2_DATA_FREE_TAG          = 0xffff
    XFS_DIR2_DATA_ALIGN_LOG         = 3
    XFS_DIR2_DATA_ALIGN             = 1 << XFS_DIR2_DATA_ALIGN_LOG
    XFS_DIR2_SPACE_SIZE             = 1 << (32 + XFS_DIR2_DATA_ALIGN_LOG)
    XFS_DIR2_LEAF_SPACE             = 1
    XFS_DIR2_LEAF_OFFSET            = XFS_DIR2_LEAF_SPACE * XFS_DIR2_SPACE_SIZE

    # 16 is the smallest directory entry size but hard-coding is not nice
    SIZEOF_SMALLEST_DIRECTORY_ENTRY = 16

    def symlink?
      @file_type == Inode::FT_SYM_LNK
    end

    def directory?
      @file_type == Inode::FT_DIRECTORY
    end

    def file?
      @file_type == Inode::FT_FILE
    end

    def device?
      @file_type == Inode::FT_CHAR  ||
      @file_type == Inode::FT_BLOCK ||
      @file_type == Inode::FT_FIFO  ||
      @file_type == Inode::FT_SOCKET
    end

    def round_up(num, base)
      return num if num % base == 0
      num + base - (num % base)
    end

    def dir_data_entsize(n, version_3_header)
      if version_3_header
        return round_up(SIZEOF_DIRECTORY2_DATA_ENTRY + n + SIZEOF_DIRECTORY2_DATA_TAG + 1, XFS_DIR2_DATA_ALIGN)
      end
      round_up(SIZEOF_DIRECTORY2_DATA_ENTRY + n + SIZEOF_DIRECTORY2_DATA_TAG, XFS_DIR2_DATA_ALIGN)
    end

    attr_reader :inode, :length, :name, :tag, :name_length
    attr_accessor :file_type

    def initialize(data, version_3_header)
      raise "XFS::DirectoryEntry.initialize: Nil directory entry data" if data.nil?
      size           = SIZEOF_DIRECTORY2_UNUSED_ENTRY
      start          = @length = @name_length = 0
      unused_entry   = DIRECTORY2_UNUSED_ENTRY.decode(data[start..size])
      if unused_entry['freetag'] == XFS_DIR2_DATA_FREE_TAG
        @length      = unused_entry['length']
        @name        = ""
        return
      end
      free_size = start
      size         = SIZEOF_DIRECTORY2_DATA_ENTRY
      @de          = DIRECTORY2_DATA_ENTRY.decode(data[start..(start + size)])
      @inode       = @de['inumber']
      @name_length = @de['name_len']
      start        += size
      # If there's a name get it.
      unless @name_length == 0
        @name     = data[start, @name_length]
        @tag      = DIRECTORY2_DATA_TAG.decode(data[start])
        @length   = free_size + dir_data_entsize(@name_length, version_3_header)
      end
      raise "XFS::Directory: DirectoryEntry length cannot be 0" if @length == 0
    end

    def dump
      out = "\#<#{self.class}:0x#{format('%08x', object_id)}>\n"
      out += "Inode   : #{inode}\n"
      out += "Len     : #{length}\n"
      out += "Name    : #{name}\n"
      out
    end
  end # class
end # module
