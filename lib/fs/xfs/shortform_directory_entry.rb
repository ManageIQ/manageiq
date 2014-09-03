$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'inode'

module XFS
  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.
  #
  # Short Form Directory Entry in a Short Form Inode.
  #
  SHORT_FORM_DIR_ENTRY = BinaryStruct.new([
    'C',   'name_len',  # name length
    'C',   'offset_byte0',
    'C',   'offset_byte1',
  ])
  SIZEOF_SHORT_FORM_DIR_ENTRY = SHORT_FORM_DIR_ENTRY.size

  SHORT_FORM_SHORT_INO = BinaryStruct.new([
    'I>',  'inode_num', # 4 byte inode number
  ])
  SIZEOF_SHORT_FORM_SHORT_INO = SHORT_FORM_SHORT_INO.size

  SHORT_FORM_LONG_INO = BinaryStruct.new([
    'Q>',  'inode_num', # 8 byte inode number
  ])
  SIZEOF_SHORT_FORM_LONG_INO = SHORT_FORM_LONG_INO.size

  class ShortFormDirEntry
    attr_reader :length, :name, :name_length, :short_inode
    attr_accessor :file_type, :inode

    def dot_entry(dots, inode_number)
      @length      = 0
      @name_length = dots
      @name        = "."
      @name        = ".." if dots == 2
      @inode       = inode_number
      # Inode Numbers will be filled in by the caller
    end

    def initialize(data, short_inode, dots = 0, inode_number = nil)
      #
      # If dots is 1 or 2 we need to construct the
      # "." and ".." directory entries.
      #
      return dot_entry(dots, inode_number) if dots
      raise "XFS::DirectoryEntry.initialize: Nil directory entry data" if data.nil?
      siz           = SIZEOF_SHORT_FORM_DIR_ENTRY
      start         = 0
      @de           = SHORT_FORM_DIR_ENTRY.decode(data[start..siz])
      @name_length     = @de['name_length']
      # If there's a name get it.
      unless @name_length == 0
        @name     = data[SIZEOF_SHORT_FORM_DIR_ENTRY, @name_length]
        start   = SIZEOF_SHORT_FORM_DIR_ENTRY + @name_length
        if short_inode
          ino_size = SIZEOF_SHORT_FORM_SHORT_INO
          @inode  = SHORT_FORM_SHORT_INO.decode(data[start..(start + ino_size)])
        else
          ino_size = SIZEOF_SHORT_FORM_LONG_INO
          @inode  = SHORT_FORM_LONG_INO.decode(data[start..(start + ino_size)])
        end
        @length    = start + ino_size
      end
      @inode    = @de['inumber']
      puts "Dir Entry is #{dump}"
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
