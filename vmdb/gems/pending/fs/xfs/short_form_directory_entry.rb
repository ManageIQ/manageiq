$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'inode'

module XFS
  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.
  #
  # Short Form Directory Entry in a Short Form Inode.
  #
  SHORT_FORM_DIRECTORY_ENTRY = BinaryStruct.new([
    'C',   'name_length',  # name length
    'C',   'offset_byte0',
    'C',   'offset_byte1',
  ])
  SIZEOF_SHORT_FORM_DIRECTORY_ENTRY = SHORT_FORM_DIRECTORY_ENTRY.size

  SHORT_FORM_SHORT_INO = BinaryStruct.new([
    'I>',  'inode_num', # 4 byte inode number
  ])
  SIZEOF_SHORT_FORM_SHORT_INO = SHORT_FORM_SHORT_INO.size

  SHORT_FORM_LONG_INO = BinaryStruct.new([
    'Q>',  'inode_num', # 8 byte inode number
  ])
  SIZEOF_SHORT_FORM_LONG_INO = SHORT_FORM_LONG_INO.size

  class ShortFormDirectoryEntry
    attr_reader :length, :name, :name_length, :short_inode
    attr_accessor :file_type, :inode

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

    def dot_entry(dots, inode_number)
      @length      = 0
      @name_length = dots
      @name        = "."
      @name        = ".." if dots == 2
      @inode       = inode_number
      # Inode Numbers will be filled in by the caller
    end

    def initialize(data, short_inode, sb, dots = nil, inode_number = nil)
      #
      # If dots is 1 or 2 we need to construct the
      # "." and ".." directory entries.
      #
      return dot_entry(dots, inode_number) if dots
      raise "XFS::ShortFormDirectoryEntry.initialize: Nil directory entry data" if data.nil?
      siz              = SIZEOF_SHORT_FORM_DIRECTORY_ENTRY
      @directory_entry = SHORT_FORM_DIRECTORY_ENTRY.decode(data[0..siz])
      @name_length     = @directory_entry['name_length']
      unless @name_length == 0
        @name_length     += 1 if sb.version_has_crc?
        @name   = data[siz, @name_length]
        start   = siz + @name_length
        if short_inode
          ino_size = SIZEOF_SHORT_FORM_SHORT_INO
          inode    = SHORT_FORM_SHORT_INO.decode(data[start..(start + ino_size)])
        else
          ino_size = SIZEOF_SHORT_FORM_LONG_INO
          inode    = SHORT_FORM_LONG_INO.decode(data[start..(start + ino_size)])
        end
        @length    = start + ino_size
        @inode     = inode['inode_num']
      end
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
