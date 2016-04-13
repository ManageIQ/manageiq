module Lvm2Thin
  class BTree
    FLAGS = { :internal => 1, :leaf => 2}

    attr_accessor :root_address

    def initialize(superblock, root_address, value_type)
      @superblock   = superblock
      @root_address = root_address
      @value_type   = value_type
    end

    def root
      @root ||= begin
        @superblock.seek root_address
        @superblock.read_struct DISK_NODE
      end
    end

    def internal?
      (root['flags'] & FLAGS[:internal]) != 0
    end

    def leaf?
      (root['flags'] & FLAGS[:leaf]) != 0
    end

    def num_entries
      @num_entries ||= root['nr_entries']
    end

    def max_entries
      @max_entries ||= root['max_entries']
    end

    def key_base
      root_address + DISK_NODE.size
    end

    def key_address(i)
      key_base + i * 8
    end

    def value_base
      key_address(max_entries)
    end

    def value_address(i)
      value_base + @value_type.size * i
    end

    def keys
      @keys ||= begin
        @superblock.seek key_base
        @superblock.read(num_entries * 8).unpack("Q#{num_entries}")
      end
    end

    def entries
      @entries ||= begin
        @superblock.seek value_base
        @superblock.read_structs @value_type, num_entries
      end
    end

    def entry_for(key)
      entries[keys.index(key)]
    end

    def to_h
      @h ||=
        Hash[0.upto(num_entries-1).collect do |i|
          k = keys[i]
          e = entries[i].kind_of?(BTree) ? entries[i].to_h : entries[i]
          [k, e]
        end]
    end

    def [](key)
      return to_h[key]
    end
  end
end # module Lvm2Thin
