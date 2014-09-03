$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")

require 'inode'

module XFS
  # ////////////////////////////////////////////////////////////////////////////
  # // Class.

  class InodeMap
    attr_reader :inode_blkno, :inode_length, :inode_boffset

    def valid_inode_size?(inode, sb)
      if (@inode_blkno + @inode_length) > sb.fsb_to_bb(sb.block_count)
        raise "XFS::InodeMap - Inode #{@inode_blkno} too large for filesystem"
      end
      $log.info "Map for Inode: #{inode}\n#{dump}\n\n" if $log
      true
    end

    def valid_inode_number?(inode, sb)
      if (@agno >= sb.sb['ag_count']) ||
         (@agbno >= sb.sb['ag_blocks']) ||
         sb.agino_to_ino(@agno, @agino) != inode
        raise "XFS::InodeMap - Bad Inode number #{inode}"
      end
      true
    end

    def initialize(inode, sb)
      #
      # Split up the inode number into its parts
      #
      @inode_number   = inode
      @agno           = sb.ino_to_agno(inode)
      @agino          = sb.ino_to_agino(inode)
      @agbno          = sb.agino_to_agbno(inode)

      valid_inode_number?(inode, sb) || return
      #
      # If the inode cluster size is the same as the blocksize or
      # smaller we get to the block by simple arithmetic
      #
      blks_per_cluster = sb.icluster_size_fsb
      @inode_length = sb.fsb_to_bb(blks_per_cluster)
      if blks_per_cluster == 1
        offset = sb.ino_to_offset(inode)
        @inode_blkno  = sb.agb_to_daddr(@agno, @agbno)
        @inode_boffset = offset << sb['inode_size_log']
        return
      elsif sb.inode_align_mask
        #
        # If the inode chunks are aligned then use simple math to
        # find the location.  Otherwise we have to do a btree
        # lookup to find the location.
        #
        offset_agbno = @agbno + sb.inode_align_mask
        chunk_agbno  = @agbno - offset_agbno
      else
        start_ino    = imap_lookup(@agno, @agino)
        chunk_agbno  = sb.agino_to_agbno(start_ino)
        offset_agbno = @agbno - chunk_agbno
      end

      @cluster_agbno = chunk_agbno + (offset_agbno / blks_per_cluster) * blks_per_cluster
      offset = (@agbno - @cluster_agbno) * sb.sb['inodes_per_blk'] + sb.ino_to_offset(inode)
      @inode_blkno  = sb.agb_to_fsb(@agno, @cluster_agbno)
      @inode_boffset = offset << sb.sb['inode_size_log']
      valid_inode_size?(inode, sb) || return
    end # initialize

    def imap_lookup(agno, agino)
      ag = get_ag(agno)
      cursor = InodeBtreeCursor.new(@sb, ag.agi, agno, XFS_BTNUM_INO)
      cursor.block_ptr = ag.agblock
      error = inobt_lookup(cursor, agino, XFS_LOOKUP_LE)
      raise "XFS::Superblock.imap_lookup: #{error}" if error
      inode_rec = inode_btree_record(cursor)
      if inode_rec.nil?
        raise "XFS::Superblock.imap_lookup: Error #{cursor.error} getting InodeBtreeRecord for inode #{agino}"
      end
      if inode_rec.start_ino > agino ||
         inode_rec.start_ino + @ialloc_inos <= agino
        raise "XFS::Superblock.imap_lookup: InodeBtreeRecord does not contain required inode #{agino}"
      end
      inode_rec.start_ino
    end # imap_lookup

    def dump
      out = "\#<#{self.class}:0x#{format('%08x', object_id)}>\n"
      out += "Inode Number : #{@inum}\n"
      out += "Alloc Grp Num: #{@agno}\n"
      out += "AG Ino       : #{@agino}\n"
      out += "AG Block Num : #{@agbno}\n"
      out += "Inode Length : #{@inode_length}\n"
      out += "Inode Blkno  : #{@inode_blkno}\n"
      out += "InoBlk Offset: #{@inode_boffset}\n"
      out += "Cluster AGBNO: #{@cluster_agbno}\n"
      out
    end
  end # Class InodeMap
end # Module XFS
