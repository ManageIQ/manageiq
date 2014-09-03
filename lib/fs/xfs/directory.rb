# require 'directory_entry'
require 'inode'
require 'directory_entry'
require 'directory_block_tail'
require 'directory_data_header'

module XFS
  DIR_LEAF_ENTRY = BinaryStruct.new([
    'I>', 'hashval',               # hash value of name
    'I>', 'address',               # address of data entry
  ])
  SIZEOF_DIR_LEAF_ENTRY = DIR_LEAF_ENTRY.size

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

    def globNames
      @ent_names ||= glob_entries.collect { |k, v| v.length == 1 ? k : [k] * v.length }.flatten.sort
    end

    def find_entry(name, type = nil)
      return nil unless glob_entries.key?(name)

      glob_entries[name].each do |entry|
        inode          = @sb.get_inode(entry.inode)
        entry.file_type = inode.file_mode_to_file_type
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
      p                   = header.size
      small_inode         = header.small_inode
      #
      # Fill In Dot and DotDot Entries Which don't exist in ShortForm Dir.
      #
      directory_entry = ShortFormDirEntry.new(nil, small_inode, DOT, @inode_obj.inode_number)
      entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
      directory_entry = ShortFormDirEntry.new(nil, small_inode, DOTDOT, header.parent_inode)
      entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
      loop do
        break if p > @data.length - 4 || @data[p, 4].nil? || p >= @sb.inode_size
        directory_entry = ShortFormDirEntry.new(@data[p..-1], small_inode)
        entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
        p += directory_entry.length
      end
      entries_by_name
    end

    def glob_extent_entries_by_linked_list
      entries_by_name           = {}
      header                    = DirDataHeader.new(@data)
      tail                      = DirBlockTail.new(@data[@sb.blockSize - SIZEOF_DIR_BLOCK_TAIL..-1])
      leaf_count                = tail.count
      total_leaves_size         = leaf_count * SIZEOF_DIR_LEAF_ENTRY
      p                         = header.header_end
      # 16 is the smallest dirent size but hard-coding is horrible
      last_directory_space      = @sb.blockSize - SIZEOF_DIR_BLOCK_TAIL - total_leaves_size - 16
      loop do
        break if p > @data.length - 4 || @data[p, 4].nil? || p >= last_directory_space
        directory_entry = DirectoryEntry.new(@data[p..-1])
        entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
        p += directory_entry.length
      end
      entries_by_name
    end

    def glob_btree_entries_by_linked_list
      entries_by_name           = {}
      data_pointer              = 0
      block_number              = 1
      # last_directory_space      = @sb.blockSize - DirectoryEntry.dir2_data_entsize(1)
      # 16 is the smallest dirent size but hard-coding is horrible
      last_directory_space      = @sb.blockSize - 16
      loop do
        header                    = DirDataHeader.new(@data[data_pointer..@sb.blockSize * block_number])
        block_pointer             = header.header_end
        data_pointer              += header.header_end
        loop do
          break if block_pointer > last_directory_space
          directory_entry = DirectoryEntry.new(@data[data_pointer..@sb.blockSize * block_number])
          entries_by_name = add_entry_by_name(entries_by_name, directory_entry)
          block_pointer += directory_entry.length
          data_pointer  += directory_entry.length
        end
        block_number += 1
        data_pointer = @sb.blockSize * (block_number - 1)
        break if data_pointer > @data.length - 4 || @data[data_pointer, 4].nil?
      end
      entries_by_name
    end

    def glob_entries_by_linked_list
      return {} if @data.nil?
      if @inode_object.data_method == :extents
        return glob_extent_entries_by_linked_list
      elsif @inode_object.data_method == :local
        return glob_short_form_entries_by_linked_list
      end
      glob_btree_entries_by_linked_list
    end
  end # class
end # module
