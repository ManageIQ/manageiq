require 'Ext4DirectoryEntry'
require 'Ext4Extent'
require 'Ext4ExtentHeader'
require 'Ext4ExtentIndex'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'MiqMemory'

module Ext4

  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  INODE = BinaryStruct.new([
    'S',  'file_mode',    # File mode (type and permission), see PF_ DF_ & FM_ below.
    'S',  'uid_lo',       # Lower 16-bits of user id.
    'L',  'size_lo',      # Lower 32-bits of size in bytes.
    'L',  'atime',        # Last access       time.
    'L',  'ctime',        # Last change       time.
    'L',  'mtime',        # Last modification time.
    'L',  'dtime',        # Time deleted.
    'S',  'gid_lo',       # Lower 16-bits of group id.
    'S',  'link_count',   # Link count.
    'L',  'blocks_lo',    # Lower 32-bits of Block count.
    'L',  'flags',        # Inode flags, see IF_ below.
    'L',  'version',      # Version.
    'a60','data',         # 60 bytes deciphered into data (symlink, indirect pointer, or extents)
    'L',  'gen_num',      # Generation number (NFS).
    'L',  'file_acl_lo',  # Lower 32-bits of File.
    'L',  'size_hi',      # Upper 32-bits of size in bytes or directory ACL.
    'L',  'obso_faddr',   # Obsoleted fragment address.
    'S',  'blocks_hi',    # Upper 16-bits of Block count.
    'S',  'file_acl_hi',  # Upper 16-bits of File ACL.
    'S',  'uid_hi',       # Upper 16-bits of user id.
    'S',  'gid_hi',       # Upper 16-bits of group id.
    'L',  'reserved2',    # Unused.
    'S',  'extra_isize',  #
    'S',  'pad1',         #
    'L',  'ctime_extra',  # extra Change             time (nsec << 2 | epoch)
    'L',  'mtime_extra',  # extra Modification       time (nsec << 2 | epoch)
    'L',  'atime_extra',  # extra Access             time (nsec << 2 | epoch)
    'L',  'crtime',       # File Creation time
    'L',  'crtime_extra', # extra File Creation Time time (nsec << 2 | epoch)
    'L',  'version_hi',   # Upper 32-bits of version (for 64-bit version)
  ])
  SIZEOF_INODE = INODE.size
  
  SYM_LNK_SIZE          = 60
  MAX_READ              = 4294967296
  DEFAULT_BLOCK_SIZE    = 1024

  # ////////////////////////////////////////////////////////////////////////////
  # // Class.

  class Inode

    # Bits 0 to 8 of file mode.
    PF_O_EXECUTE  = 0x0001  # owner execute
    PF_O_WRITE    = 0x0002  # owner write
    PF_O_READ     = 0x0004  # owner read
    PF_G_EXECUTE  = 0x0008  # group execute
    PF_G_WRITE    = 0x0010  # group write
    PF_G_READ     = 0x0020  # group read
    PF_U_EXECUTE  = 0x0040  # user execute
    PF_U_WRITE    = 0x0080  # user write
    PF_U_READ     = 0x0100  # user read

    # For accessor convenience.
    MSK_PERM_OWNER = (PF_O_EXECUTE | PF_O_WRITE | PF_O_READ)
    MSK_PERM_GROUP = (PF_G_EXECUTE | PF_G_WRITE | PF_G_READ)
    MSK_PERM_USER  = (PF_U_EXECUTE | PF_U_WRITE | PF_U_READ)

    # Bits 9 to 11 of file mode.
    DF_STICKY     = 0x0200
    DF_SET_GID    = 0x0400
    DF_SET_UID    = 0x0800

    # Bits 12 to 15 of file mode.
    FM_FIFO       = 0x1000  # fifo device (pipe)
    FM_CHAR       = 0x2000  # char device
    FM_DIRECTORY  = 0x4000  # directory
    FM_BLOCK_DEV  = 0x6000  # block device
    FM_FILE       = 0x8000  # regular file
    FM_SYM_LNK    = 0xa000  # symbolic link
    FM_SOCKET     = 0xc000  # socket device

    # For accessor convenience.
    MSK_FILE_MODE = 0xf000
    MSK_IS_DEV    = (FM_FIFO | FM_CHAR | FM_BLOCK_DEV | FM_SOCKET)

    # Inode flags.
    IF_SECURE_DEL = 0x00000001  # wipe when deleting
    IF_KEEP_COPY  = 0x00000002  # never delete
    IF_COMPRESS   = 0x00000004  # compress content
    IF_SYNCHRO    = 0x00000008  # don't cache
    IF_IMMUTABLE  = 0x00000010  # file cannot change
    IF_APPEND     = 0x00000020  # always append
    IF_NO_DUMP    = 0x00000040  # don't cat
    IF_NO_ATIME   = 0x00000080  # don't update atime
    IF_DIRTY      = 0x00000100
    IF_COMPR_CL   = 0x00000200  # One or more compressed clusters
    IF_NOCOMPR    = 0x00000400  # Don't compress
    IF_ECOMPR     = 0x00000800  # Compression error
    IF_HASH_INDEX = 0x00001000  # if dir, has hash index
    IF_AFS_DIR    = 0x00002000  # AFS directory
    IF_JOURNAL    = 0x00004000  # if using journal, is journal inode
    IF_NOTAIL     = 0x00008000  # file tail should not be merged
    IF_DIRSYNC    = 0x00010000  # dirsync behaviour (directories only)
    IF_TOPDIR     = 0x00020000  # Top of directory hierarchies
    IF_HUGE_FILE  = 0x00040000  # Set to each huge file
    IF_EXTENTS    = 0x00080000  # Inode uses extents
    IF_EA_INODE   = 0x00200000  # Inode used for large EA
    IF_EOFBLOCKS  = 0x00400000  # Blocks allocated beyond EOF
    IF_FLAGS = (IF_SECURE_DEL | IF_KEEP_COPY | IF_COMPRESS | IF_SYNCHRO | IF_IMMUTABLE | IF_APPEND | IF_NO_DUMP | IF_NO_ATIME | IF_DIRTY | IF_COMPR_CL | IF_NOCOMPR | IF_ECOMPR | IF_HASH_INDEX | IF_AFS_DIR | IF_JOURNAL | IF_NOTAIL | IF_DIRSYNC | IF_TOPDIR | IF_HUGE_FILE | IF_EXTENTS | IF_EA_INODE | IF_EOFBLOCKS)
    
    FLAG_STR = {
      IF_SECURE_DEL => 'IF_SECURE_DEL',
      IF_KEEP_COPY  => 'IF_KEEP_COPY',
      IF_COMPRESS   => 'IF_COMPRESS',
      IF_SYNCHRO    => 'IF_SYNCHRO',
      IF_IMMUTABLE  => 'IF_IMMUTABLE',
      IF_APPEND     => 'IF_APPEND',
      IF_NO_DUMP    => 'IF_NO_DUMP',
      IF_NO_ATIME   => 'IF_NO_ATIME',
      IF_DIRTY      => 'IF_DIRTY',
      IF_COMPR_CL   => 'IF_COMPR_CL',
      IF_NOCOMPR    => 'IF_NOCOMPR',
      IF_ECOMPR     => 'IF_ECOMPR',
      IF_HASH_INDEX => 'IF_HASH_INDEX',
      IF_AFS_DIR    => 'IF_AFS_DIR',
      IF_JOURNAL    => 'IF_JOURNAL',
      IF_NOTAIL     => 'IF_NOTAIL',
      IF_DIRSYNC    => 'IF_DIRSYNC',
      IF_TOPDIR     => 'IF_TOPDIR',
      IF_HUGE_FILE  => 'IF_HUGE_FILE',
      IF_EXTENTS    => 'IF_EXTENTS',
      IF_EA_INODE   => 'IF_EA_INODE',
      IF_EOFBLOCKS  => 'IF_EOFBLOCKS'
    }

    # Lookup table for File Mode to File Type.
    @@FM2FT = {
      Inode::FM_FIFO      => DirectoryEntry::FT_FIFO,
      Inode::FM_CHAR      => DirectoryEntry::FT_CHAR,
      Inode::FM_DIRECTORY => DirectoryEntry::FT_DIRECTORY,
      Inode::FM_BLOCK_DEV => DirectoryEntry::FT_BLOCK,
      Inode::FM_FILE      => DirectoryEntry::FT_FILE,
      Inode::FM_SYM_LNK   => DirectoryEntry::FT_SYM_LNK,
      Inode::FM_SOCKET    => DirectoryEntry::FT_SOCKET
    }

    attr_reader :mode, :flags, :symlnk, :pos

    def initialize(buf, superblock, inum)
      raise "Ext4::Inode.initialize: Nil buffer" if buf.nil?
      @in = INODE.decode(buf)

      @sb    = superblock
      @inum  = inum
      @mode  = @in['file_mode']
      @flags = @in['flags']

      if self.isSymLink? and self.length < SYM_LNK_SIZE
        @data_method = nil
        @symlnk = @in['data']
      elsif hasExtents?
        @data_method = :extents
      else
        @data_method = :indirect
      end

      rewind
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Method for data access
    def rewind
      @pos = 0
    end

    def seek(offset, method = IO::SEEK_SET)
      @pos = case method
        when IO::SEEK_SET then offset
        when IO::SEEK_CUR then @pos + offset
        when IO::SEEK_END then self.length - offset
      end
      @pos = 0           if @pos < 0
      @pos = self.length if @pos > self.length
      return @pos
    end

    def read(nbytes = self.length)
      raise "Ext4::Inode.read: Can't read 4G or more at a time (use a smaller read size)" if nbytes >= MAX_READ
      return nil if @pos >= self.length

      # Handle symbolic links.
      if self.symlnk
        out = self.symlnk[@pos...nbytes]
        @pos += nbytes
        return out
      end
      nbytes = self.length - @pos if @pos + nbytes > self.length

      # get data.
      start_block, start_byte, end_block, end_byte, nblocks = pos_to_block(@pos, nbytes)
      out = read_blocks(start_block, nblocks)
      @pos += nbytes
      return out[start_byte, nbytes]
    end

    def write(buf, len = buf.length)
      raise "Ext4::Inode.write: Write functionality is not yet supported on Ext4."
      @dirty = true
    end


    # ////////////////////////////////////////////////////////////////////////////
    # // Class helpers & accessors.

    def uid
      @uid ||= (@in['uid_hi'] << 16) | @in['uid_lo']
    end

    def gid
      @gid ||= (@in['gid_hi'] << 16) | @in['gid_lo']
    end

    def nblocks
      @nblocks ||= (@in['blocks_hi'] << 32) | @in['blocks_lo']
    end

    def length
      @length ||= (@in['size_hi'] << 32) | @in['size_lo']
    end

    def isDir?
      modeSet?(FM_DIRECTORY)
    end

    def isFile?
      modeSet?(FM_FILE)
    end

    def isDev?
      return (@mode & MSK_IS_DEV) > 0
    end

    def isSymLink?
      modeSet?(FM_SYM_LNK)
    end

    def isHashedDir?
      isDir? && flagSet?(IF_HASH_INDEX)
    end

    def hasExtents?
      flagSet?(IF_EXTENTS)
    end

    def aTime
      @atime ||= Time.at(@in['atime'])
    end

    def cTime
      @ctime ||= Time.at(@in['ctime'])
    end

    def mTime
      @mtime ||= Time.at(@in['mtime'])
    end

    def dTime
      @dtime ||= Time.at(@in['dtime'])
    end

    def permissions
      @permissions ||= @in['file_mode'] & (MSK_PERM_OWNER | MSK_PERM_GROUP | MSK_PERM_USER)
    end

    def ownerPermissions
      @owner_permissions ||= @in['file_mode'] & MSK_PERM_OWNER
    end

    def groupPermissions
      @group_permissions ||= @in['file_mode'] & MSK_PERM_GROUP
    end

    def userPermissions
      @user_permissions  ||= @in['file_mode'] & MSK_PERM_USER
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Utility functions.

    def fileModeToFileType
      return @@FM2FT[@mode & MSK_FILE_MODE]
    end

    def modeSet?(bit)
      return (@mode  & bit) == bit
    end

    def flagSet?(bit)
      return (@flags & bit) == bit
    end

    def flags_to_s
      str_flags = []
      FLAG_STR.each_key do |flag|
        str_flags << FLAG_STR[flag] if flagSet?(flag)
      end
      str_flags.join(' ')
    end

    def dump
      out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
      out += "Inode Number : #{@inum}\n"
      out += "File mode    : 0x#{'%04x' % @in['file_mode']}\n"
      out += "UID          : #{self.uid}\n"
      out += "Size         : #{self.length}\n"
      out += "ATime        : #{self.aTime}\n"
      out += "CTime        : #{self.cTime}\n"
      out += "MTime        : #{self.mTime}\n"
      out += "DTime        : #{self.dTime}\n"
      out += "GID          : #{self.gid}\n"
      out += "Link count   : #{@in['link_count']}\n"
      out += "Block count  : #{self.nblocks}\n"
      out += "Flags        : #{flags_to_s}\n"
      extra = @flags - (@flags & IF_FLAGS)
      out << "  Extra Flags: 0x#{'%08x' % extra}\n" if extra != 0
      out += "Version      : #{@in['version']}\n"
      out += "Data         : \n#{@in['data'].hex_dump}"
      out += "Generation   : 0x#{'%08x' % @in['gen_num']}\n"
      out += "Ext attrib   : 0x#{'%08x' % @in['ext_attrib']}\n"
      out += "Frag blk adrs: 0x#{'%08x' % @in['frag_blk']}\n"
      out += "Frag index   : 0x#{'%02x' % @in['frag_idx']}\n"
      out += "Frag size    : 0x#{'%02x' % @in['frag_siz']}\n"
      return out
    end

    private

    # NB: pos is 0-based, while len is 1-based
    def pos_to_block(pos, len)
      startBlock, startByte = pos.divmod(@sb.blockSize)
      endBlock, endByte = (pos + len - 1).divmod(@sb.blockSize)
      nblocks = endBlock - startBlock + 1
      return startBlock, startByte, endBlock, endByte, nblocks
    end

    def read_blocks(startBlock, nblocks = 1)
      out = MiqMemory.create_zero_buffer(nblocks * @sb.blockSize)
      raise "Ext4::Inode.read_blocks: startBlock=<#{startBlock}> is greater than #{data_block_pointers.length}" if startBlock > data_block_pointers.length - 1
      1.upto(nblocks) do |i|
        block_index = startBlock + i - 1
        raise "Ext4::Inode.read_blocks: blockIndex=<#{block_index}> is greater than #{data_block_pointers.length}" if block_index > data_block_pointers.length - 1
        block = data_block_pointers[block_index]
        data  = @sb.getBlock(block)
        out[(i - 1) * @sb.blockSize, @sb.blockSize] = data
      end
      return out
    end

    def extent_to_block_pointers(extent, bplen)
      block_pointers = []
      # Fill in the missing blocks with 0-blocks
      block_pointers << 0 while (bplen + block_pointers.length) < extent.block
      1.upto(extent.length) { |i| block_pointers << extent.start + i - 1 }
      block_pointers
    end

    def expected_blocks
      @expected_blocks ||= begin
        quotient, remainder = self.length.divmod(@sb.blockSize)
        quotient + ( (remainder > 0) ? 1 : 0)
      end
    end

    def block_pointers_via_extents
      block_pointers = []

      @extent_header = ExtentHeader.new(@in['data'])

      if @extent_header.depth == 0
        1.upto(@extent_header.entries) do |i|
          extent = Extent.new(@in['data'][SIZEOF_EXTENT_HEADER + SIZEOF_EXTENT*(i-1), SIZEOF_EXTENT])
          block_pointers.concat extent_to_block_pointers(extent, block_pointers.length)
        end
      else
        1.upto(@extent_header.entries) do |i|
          extent_index    = ExtentIndex.new(@in['data'][SIZEOF_EXTENT_HEADER + SIZEOF_EXTENT_INDEX*(i-1), SIZEOF_EXTENT_INDEX])
          leaf_block      = @sb.getBlock(extent_index.leaf)
          extent_header   = ExtentHeader.new(leaf_block)
          1.upto(extent_header.entries) do |j|
            extent = Extent.new(leaf_block[SIZEOF_EXTENT_HEADER + SIZEOF_EXTENT*(j-1), SIZEOF_EXTENT])
            block_pointers.concat extent_to_block_pointers(extent, block_pointers.length)
          end
        end
      end

      block_pointers
    end

    def read_block_pointers(block)
      @sb.getBlock(block).unpack('L*')
    end

    def block_pointers_via_triple_indirect(triple_indirect_block_num, bplen = 0)
      block_pointers = []
      if (bplen + block_pointers.length) < expected_blocks
        read_block_pointers(triple_indirect_block_num).each do |double_indirect_block_num|
          if (bplen + block_pointers.length) < expected_blocks
            block_pointers.concat block_pointers_via_double_indirect(double_indirect_block_num, bplen + block_pointers.length)
          end
        end
      end
      block_pointers
    end

    def block_pointers_via_double_indirect(double_indirect_block_num, bplen = 0)
      block_pointers = []
      if (bplen + block_pointers.length) < expected_blocks
        read_block_pointers(double_indirect_block_num).each do |single_indirect_block_num| 
          if (bplen + block_pointers.length) < expected_blocks
            block_pointers.concat block_pointers_via_single_indirect(single_indirect_block_num, bplen + block_pointers.length)
          end
        end
      end
      block_pointers
    end

    def block_pointers_via_single_indirect(single_indirect_block_num, bplen = 0)
      block_pointers = []
      if (bplen + block_pointers.length) < expected_blocks
        read_block_pointers(single_indirect_block_num).each do |bp|
          block_pointers << bp if (bplen + block_pointers.length < expected_blocks)
        end
      end
      block_pointers
    end

    def block_pointers_via_indirect
      block_pointers = []

      # NOTE: Unpack the direct block pointers separately.
      @in['data'][0,48].unpack('L12').each { |bp| block_pointers << bp if (block_pointers.length < expected_blocks) }

      single_indirect_block_num = @in['data'][48,4].unpack('L').first
      block_pointers.concat block_pointers_via_single_indirect(single_indirect_block_num, block_pointers.length)

      double_indirect_block_num = @in['data'][52,4].unpack('L').first
      block_pointers.concat block_pointers_via_double_indirect(double_indirect_block_num, block_pointers.length)

      triple_indirect_block_num = @in['data'][56,4].unpack('L').first
      block_pointers.concat block_pointers_via_triple_indirect(triple_indirect_block_num, block_pointers.length)

      block_pointers
    end

    def data_block_pointers
      if @data_block_pointers.nil?
        @data_block_pointers = block_pointers_via_extents          if (@data_method == :extents)
        @data_block_pointers = block_pointers_via_indirect         if (@data_method == :indirect)
        raise "Ext4::Inode.block_pointers: Actual Block Pointers <#{@data_block_pointers.length}> does not match Expected <#{expected_blocks}>" if expected_blocks != @data_block_pointers.length
      end
      @data_block_pointers
    end

  end
end
