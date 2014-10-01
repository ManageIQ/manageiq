require 'inode'
require 'directory_entry'
require 'directory_block_tail'
require 'directory_data_header'
require 'short_form_header'
require 'short_form_directory_entry'

module XFS
  DIRECTORY_LEAF_ENTRY = BinaryStruct.new([
    'I>', 'hashval',               # hash value of name
    'I>', 'address',               # address of data entry
  ])
  SIZEOF_DIRECTORY_LEAF_ENTRY = DIRECTORY_LEAF_ENTRY.size

  class Directory
    DOT                     = 1
    DOTDOT                  = 2
    ROOT_DIRECTORY          = 128

    attr_reader :inode_number, :inode_object

    def initialize(sb, inode_number = ROOT_DIRECTORY)
      raise "XFS::Directory: Nil superblock"   if sb.nil?
      @sb           = sb
      @inode_number = inode_number
      @inode_object = sb.get_inode(inode_number)
      raise "XFS::Directory: INODE=#{inode_number} is NOT a DIRECTORY" unless @inode_object.directory?
      @data         = @inode_object.read
    end

    def glob_names
      @ent_names ||= glob_entries.collect { |k, v| v.length == 1 ? k : [k] * v.length }.flatten.sort
    end

    def find_entry(name, type = nil)
      return nil unless glob_entries.key?(name)

      glob_entries[name].each do |entry|
        @inode_object    = @sb.get_inode(entry.inode)
        entry.file_type = @inode_object.file_mode_to_file_type
        return entry if (entry.file_type == type) || type.nil?
      end
      nil
    end

    private

    def glob_entries
      @entries_by_name ||= glob_entries_by_linked_list
    end

    def add_entry_by_name(entries_by_name, directory_entry)
      return entries_by_name unless directory_entry.name_length > 0
      entries_by_name[directory_entry.name] ||= []
      entries_by_name[directory_entry.name] << directory_entry
      entries_by_name
    end

    def glob_short_form_entries_by_linked_list
      entries_by_name = {}
      header              = ShortFormHeader.new(@data)
      data_pointer        = header.size
      small_inode         = header.small_inode
      #
      # Fill In Dot and DotDot Entries Which don't exist in ShortForm Dir.
      #
      directory_entry = ShortFormDirectoryEntry.new(nil, small_inode, @sb, DOT, @inode_object.inode_number)
      entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
      directory_entry = ShortFormDirectoryEntry.new(nil, small_inode, @sb, DOTDOT, header.parent_inode)
      entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
      loop do
        break if data_pointer > @data.length - 4 || @data[data_pointer, data_pointer + 4].nil?
        directory_entry = ShortFormDirectoryEntry.new(@data[data_pointer..@inode_object.length], small_inode, @sb)
        entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
        data_pointer    += directory_entry.length
      end
      entries_by_name
    end

    def glob_single_extent_entries_by_linked_list
      entries_by_name           = {}
      header                    = DirectoryDataHeader.new(@data, @sb)
      data_pointer              = header.header_end
      tail                      = DirectoryBlockTail.new(@data[@sb.block_size - SIZEOF_DIRECTORY_BLOCK_TAIL..-1])
      total_leaves_size         = tail.count * SIZEOF_DIRECTORY_LEAF_ENTRY
      last_directory_space      = @sb.block_size - DirectoryEntry::SIZEOF_SMALLEST_DIRECTORY_ENTRY -
                                  SIZEOF_DIRECTORY_BLOCK_TAIL - total_leaves_size
      loop do
        break if data_pointer > @data.length - 4 || @data[data_pointer, 4].nil? || data_pointer > last_directory_space
        directory_entry = DirectoryEntry.new(@data[data_pointer..-1], header.version_3)
        entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
        data_pointer    += directory_entry.length
      end
      entries_by_name
    end

    def glob_extent_or_btree_entries_by_linked_list
      entries_by_name           = {}
      data_pointer              = 0
      block_number              = 1
      last_directory_space      = @sb.block_size - DirectoryEntry::SIZEOF_SMALLEST_DIRECTORY_ENTRY
      if @inode_object.data_method == :extents
        return glob_single_extent_entries_by_linked_list if @inode_object.in['num_extents'] == 1
      end
      loop do
        header                = DirectoryDataHeader.new(@data[data_pointer..@sb.block_size * block_number], @sb)
        block_pointer         = header.header_end
        data_pointer          += header.header_end
        loop do
          break if block_pointer > last_directory_space
          directory_entry = DirectoryEntry.new(@data[data_pointer..@sb.block_size * block_number], header.version_3)
          entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
          block_pointer   += directory_entry.length
          data_pointer    += directory_entry.length
        end
        block_number += 1
        data_pointer = @sb.block_size * (block_number - 1)
        break if data_pointer > @data.length - 4 || @data[data_pointer, 4].nil?
      end
      entries_by_name
    end

    def glob_entries_by_linked_list
      return {} if @data.nil?
      if @inode_object.data_method == :extents || @inode_object.data_method == :btree
        return glob_extent_or_btree_entries_by_linked_list
      elsif @inode_object.data_method == :local
        return glob_short_form_entries_by_linked_list
      end
      {}
    end
  end # class
end # module
