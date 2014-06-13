$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext4

  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  DIR_ENTRY_ORIGINAL = BinaryStruct.new([
    'L',  'inode_val',  # Inode address of metadata.
    'S',  'entry_len',  # Length of entry.
    'S',  'name_len',   # Length of name.
  ])
  # Here follows the name in ASCII.
  SIZEOF_DIR_ENTRY_ORIGINAL = DIR_ENTRY_ORIGINAL.size

  DIR_ENTRY_NEW = BinaryStruct.new([
    'L',  'inode_val',  # Inode address of metadata.
    'S',  'entry_len',  # Length of entry.
    'C',  'name_len',   # Length of name.
    'C',  'file_type',  # Type of file (see FT_ below).
  ])
  # Here follows the name in ASCII.
  SIZEOF_DIR_ENTRY_NEW = DIR_ENTRY_NEW.size

  class DirectoryEntry

    FT_UNKNOWN    = 0
    FT_FILE       = 1
    FT_DIRECTORY  = 2
    FT_CHAR       = 3
    FT_BLOCK      = 4
    FT_FIFO       = 5
    FT_SOCKET     = 6
    FT_SYM_LNK    = 7

    attr_reader :inode, :len, :name
    attr_accessor :fileType

    def initialize(data, new_entry = true)
      raise "Ext4::DirectoryEntry.initialize: Nil directory entry data" if data.nil?
      @isNew    = new_entry
      siz       = @isNew ? SIZEOF_DIR_ENTRY_NEW               : SIZEOF_DIR_ENTRY_ORIGINAL
      @de       = @isNew ? DIR_ENTRY_NEW.decode(data[0..siz]) : DIR_ENTRY_ORIGINAL.decode(data[0..siz])
      # If there's a name get it.
      @name     = data[siz, @de['name_len']] if @de['name_len'] != 0
      @inode    = @de['inode_val']
      @len      = @de['entry_len']
      @fileType = @de['file_type'] if @isNew
    end

    def isDir?
      return @fileType == FT_DIRECTORY
    end

    def isSymLink?
      return @fileType == FT_SYM_LNK
    end
    
    def fileTypeString
      return "UNKNOWN"   if @fileType == FT_UNKNOWN
      return "FILE"      if @fileType == FT_FILE
      return "DIRECTORY" if @fileType == FT_DIRECTORY
      return "CHAR"      if @fileType == FT_CHAR
      return "BLOCK"     if @fileType == FT_BLOCK
      return "FIFO"      if @fileType == FT_FIFO
      return "SOCKET"    if @fileType == FT_SOCKET
      return "SYMLINK"   if @fileType == FT_SYM_LNK
    end

    def dump
      out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
      out += "Inode   : #{self.inode}\n"
      out += "Len     : #{self.len}\n"
      out += "Name len: 0x#{'%04x' % @de['name_len']}\n"
      out += "Type    : #{self.fileTypeString}\n" if @isNew
      out += "Name    : #{self.name}\n"
    end

    end #class
end #module
