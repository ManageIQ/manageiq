$:.push("#{File.dirname(__FILE__)}")
require 'MiqLargeFile'
require 'MiqMemory'
require 'binary_struct'

require 'zlib'

module QcowDisk

  QCOW_HEADER_PARTIAL = BinaryStruct.new([
    'A4', 'magicNumber',
    'N', 'version',
  ])
  SIZEOF_QCOW_HEADER_PARTIAL = QCOW_HEADER_PARTIAL.size

  QCOW_HEADER_V1 = BinaryStruct.new([
    'A4', 'magicNumber',
    'N', 'version',
    'N', 'backing_filename_offset_hi',
    'N', 'backing_filename_offset_lo',
    'N', 'backing_filename_size',
    'N', 'mtime',
    'N', 'size_hi',
    'N', 'size_lo',
    'C', 'cluster_bits',
    'C', 'l2_bits',
    'N', 'crypt_method',
    'N', 'l1_table_offset_hi',
    'N', 'l1_table_offset_lo',
  ])
  SIZEOF_QCOW_HEADER_V1 = QCOW_HEADER_V1.size

  QCOW_HEADER_V2 = BinaryStruct.new([
    'A4', 'magicNumber',
    'N', 'version',
    'N', 'backing_filename_offset_hi',
    'N', 'backing_filename_offset_lo',
    'N', 'backing_filename_size',
    'N', 'cluster_bits',
    'N', 'size_hi',
    'N', 'size_lo',
    'N', 'crypt_method',
    'N', 'l1_size',
    'N', 'l1_table_offset_hi',
    'N', 'l1_table_offset_lo',
    'N', 'refcount_table_offset_hi',
    'N', 'refcount_table_offset_lo',
    'N', 'refcount_table_clusters',
    'N', 'number_of_snapshots',
    'N', 'snapshots_offset_hi',
    'N', 'snapshots_offset_lo',
  ])
  SIZEOF_QCOW_HEADER_V2 = QCOW_HEADER_V2.size

  # indicate that the refcount of the referenced cluster is exactly one.
  QCOW_OFLAG_COPIED     = (1 << 63)

  # indicate that the cluster is compressed (they never have the copied flag)
  QCOW_OFLAG_COMPRESSED = (1 << 62)

  LO63_MASK = ~QCOW_OFLAG_COPIED
  LO62_MASK = ~(QCOW_OFLAG_COPIED | QCOW_OFLAG_COMPRESSED)

  L1E_OFFSET_MASK                 = 0x00fffffffffffe00
  L2E_OFFSET_MASK                 = 0x00fffffffffffe00
  L2E_COMPRESSED_OFFSET_SIZE_MASK = 0x3fffffffffffffff

  SECTOR_SIZE       = 512
  ZLIB_WINDOW_BITS  = -12

  def d_init
    self.diskType = "QCOW"
    self.blockSize = SECTOR_SIZE

    if self.dInfo.mountMode == nil || self.dInfo.mountMode == "r"
      self.dInfo.mountMode = "r"
      @fileMode = "r"
    elsif self.dInfo.mountMode == "rw"
      @fileMode = "r+"
    else
      raise "Unrecognized mountMode: #{self.dInfo.mountMode}"
    end

    @filename = dInfo.fileName
    @dOffset = self.dInfo.offset
    @downstreamDisk = self.dInfo.downstreamDisk
    self.diskType = "#{self.diskType}-#{@downstreamDisk.diskType}" if @downstreamDisk
  end

  def getBase
    return self
  end

  def d_read(pos, len, offset = 0)
    pos += @dOffset if @dOffset
    return nil if pos >= @endByteAddr
    len = @endByteAddr - pos if (pos + len) > @endByteAddr

    sector_num, sector_offset = pos.divmod(SECTOR_SIZE)
    sector_count = ((pos+len-1)/SECTOR_SIZE) - sector_num + 1

    read_buf  = read_sectors(sector_num, sector_count)
    buf       = read_buf[sector_offset, len]

    return buf
  end

  def d_write(pos, buf, len, offset = 0)
    raise "QcowDisk#d_write not implemented"
  end

  def d_close
    [@backing_file_handle, @file_handle].each do |h|
      next if h.nil?
      h.close
      h = nil
    end
  end

  # Disk size in sectors.
  def d_size
    uint64(header, 'size') / @blockSize
  end

  def version
    @version ||= header['version']
  end

  def backing_file_name
    @backing_file_name ||= begin
      if backing_filename_offset > 0
        file_handle.seek(backing_filename_offset, IO::SEEK_SET)
        backing_fname = file_handle.read(backing_filename_size)
        bfn = File.expand_path File.join(File.dirname(@filename), backing_fname)

        #
        # Check if the backing file is a logical volume from a direct lun volume group.
        #
        bfn_test = File.expand_path File.join(File.dirname(@filename), File.basename(bfn))
        use_lv = false
        if (avm = @dInfo.applianceVolumeManager)
          use_lv = avm.lvHash.has_key?(bfn_test)
        end
        if (!File.symlink?(bfn) && !File.file?(bfn)) && use_lv
          bfn_test
        else
          bfn
        end
      else
        ""
      end
    end
  end

  def cluster_sectors
    @cluster_sectors ||= 1 << (cluster_bits - 9)
  end

  def total_sectors
    @total_sectors ||= size / SECTOR_SIZE
  end

  private

  def offset2sector(offset)
    offset / SECTOR_SIZE
  end

  def sector2offset(sector)
    sector * SECTOR_SIZE
  end

  def index_in_cluster(offset)
    offset2sector(offset) & (total_sectors - 1)
  end

  def cluster_bits
    @cluster_bits ||= header['cluster_bits']
  end

  def cluster_size
    @cluster_size ||= 1 << cluster_bits
  end

  def l2_bits
    @l2_bits ||= begin
      case version
      when 1
        header['l2bits']
      when 2
        cluster_bits - 3
      else
        raise "Unknown QCOW Version: #{version}"
      end
    end
  end

  def l2_size
    @l2_size ||= 1 << l2_bits
  end

  def l1_bits
    @l1_bits ||= 64 - l2_bits - cluster_bits
  end

  def l1_table_offset
    @l1_table_offset ||= uint64(header, 'l1_table_offset')
  end

  def l1_size_minimum
    @l1_size_minimum ||= begin
      shift = cluster_bits + l2_bits
      (size + (1 << shift) - 1) >> shift
#      (size / (cluster_size * l2_size)).round_up(cluster_size)
    end
  end

  def l1_size
    @l1_size ||= begin
      case version
      when 1
       shift = cluster_bits + l2_bits
       (size + (1 << shift) - 1) >> shift
      when 2
        header['l1_size']
      else
        raise "Unknown QCOW Version: #{version}"
      end
    end
  end

  def l1_table
    @l1_table ||= begin
      raise "l1_size (#{l1_size}) < l1_size_minimum (#{l1_size_minimum})" if (l1_size < l1_size_minimum)
      file_handle.seek(l1_table_offset, IO::SEEK_SET)
      read_entries(l1_size)
    end
  end

  def l2_table(l2_table_offset)
    @l2_table ||= {}
    @l2_table[l2_table_offset] ||= begin
      file_handle.seek(l2_table_offset, IO::SEEK_SET)
      read_entries(l2_size)
    end
    @l2_table[l2_table_offset]
  end

  def read_entries(n)
    entries = Array.new
    file_handle.read(n * SIZEOF_UINT64).unpack("N*").each_slice(2) { |hi, lo| entries << uint64_from_hi_lo(hi, lo) }
    entries
  end

  def refcount_table_clusters
    return nil if version == 1
    @refcount_table_clusters ||= header['refcount_table_clusters']
  end

  def refcount_table_offset
    return nil if version == 1
    @refcount_table_offset ||= uint64(header, 'refcount_table_offset')
  end

  def snapshots_count
    return nil if version == 1
    @snaphshots_count ||= header['number_of_snapshots']
  end

  def snapshots_offset
    return nil if version == 1
    @snapshots_offset ||= uint64(header, 'snapshots_offset')
  end

  def crypt_method
    @crypt_method ||= header['crypt_method']
  end

  def backing_filename_size
    @backing_filename_size ||= [header['backing_filename_size'], 1023].min
  end

  def backing_filename_offset
    @backing_filename_offset ||= uint64(header, 'backing_filename_offset')
  end

  def decompress_buffer(buf)
    raise "decompression buffer cannot be nil" if buf.nil?
    
    zi = Zlib::Inflate.new(ZLIB_WINDOW_BITS)
    rv = zi.inflate(buf)
    zi.finish
    zi.close
    return rv
  end

  def decompress_cluster(cluster_offset)
    cluster_offset &= L2E_COMPRESSED_OFFSET_SIZE_MASK
    coffset         = cluster_offset & cluster_offset_mask
    nb_sectors      = ((cluster_offset >> csize_shift) & csize_mask) + 1
    csize           = nb_sectors * SECTOR_SIZE

    file_handle.seek(coffset, IO::SEEK_SET)
    buf = file_handle.read(csize)
    return decompress_buffer(buf)
  end

  #
  # Data is not on the COW image - read from the base image / backing file
  #
  def read_backing_file(sector_num, nb_sectors)
    n =
      if ((sector_num + nb_sectors) <= total_sectors)
        nb_sectors
      elsif (sector_num >= total_sectors)
        0
      else
        total_sectors - sector_num
      end

    backing_buffer = ''

    if n > 0
      nbytes   = SECTOR_SIZE * n
      boffset  = sector_num * SECTOR_SIZE
      backing_file_handle.seek(boffset, IO::SEEK_SET)
      backing_buffer = backing_file_handle.read(nbytes)
      raise "QCOW Backing File read returned NIL" if backing_buffer.nil?
      raise "QCOW Backing File read returned #{rbuf.length} bytes - requested #{nbytes} bytes" if backing_buffer.length != nbytes
    end

    backing_buffer << MiqMemory.create_zero_buffer(SECTOR_SIZE * (nb_sectors - n))
    backing_buffer
  end

  def read_image_file(file_offset, nbytes)
    raise "QCOW size #{size} is less than computed offset (#{file_offset})" if file_offset > size
    file_handle.seek(file_offset, IO::SEEK_SET)
    buffer = file_handle.read(nbytes)
    raise "QCOW Image File read returned NIL" if buffer.nil?
    raise "QCOW Image File read returned #{buffer.to_s.length} bytes - requested #{nbytes} bytes" if buffer.length != nbytes
    buffer
  end

  def read_sectors(sector_num, nb_sectors)
    buf = ""

    while nb_sectors > 0
      index_in_cluster = sector_num & (cluster_sectors - 1)
      n                = cluster_sectors - index_in_cluster
      n                = nb_sectors if (n > nb_sectors)
      nbytes           = SECTOR_SIZE * n

      cluster_offset = get_cluster_offset(sector_num * SECTOR_SIZE)

      if cluster_offset == 0
        if backing_file_name.empty?
          rbuf = MiqMemory.create_zero_buffer(nbytes)
        else
          rbuf = read_backing_file(sector_num, n)
        end
      elsif compressed?(cluster_offset)
        rbuf = decompress_cluster(cluster_offset)
        rbuf = rbuf[index_in_cluster * SECTOR_SIZE, nbytes]
      else
        cluster_offset &= L2E_OFFSET_MASK
        file_offset = cluster_offset + (index_in_cluster * SECTOR_SIZE)
        rbuf = read_image_file(file_offset, nbytes)
      end

      buf        << rbuf
      nb_sectors -= n
      sector_num += n
    end

    buf
  end

  def get_cluster_offset(offset)
    cluster_offset   = 0
    l1_index         = offset >> (l2_bits + cluster_bits)

    if (l1_index < l1_size)
      l2_offset  = l1_table[l1_index] & L1E_OFFSET_MASK
      if l2_offset > 0
        l2_index   = (offset >> cluster_bits) & (l2_size - 1)
        cluster_offset = l2_table(l2_offset)[l2_index] & ~copied_mask
      end
    end

    cluster_offset
  end

  def file_handle
    @file_handle ||= begin
      if @downstreamDisk
        $log.debug "QcowDisk.file_handle: downstreamDisk #{@downstreamDisk.dInfo.fileName}"
        @downstreamDisk
      else
        $log.debug "QcowDisk.file_handle: file #{@filename}"
        MiqLargeFile.open(@filename, @fileMode)
      end
    end
  end

  def backing_file_handle
    return nil if backing_file_name.empty?
    @backing_file_handle ||= begin
      dInfo = OpenStruct.new
      dInfo.fileName = backing_file_name
      $log.debug "QcowDisk.backing_file_handle: file #{@filename}"
      $log.debug "QcowDisk.backing_file_handle: opening backing file #{backing_file_name}"
      if (avm = @dInfo.applianceVolumeManager)
        if (bfh = avm.lvHash[dInfo.fileName])
          $log.debug "QcowDisk.backing_file_handle: using applianceVolumeManager for #{backing_file_name}"
          bfh.dInfo.applianceVolumeManager = avm
          bfh.dInfo.fileName = backing_file_name
          #
          # Here, we need to probe the disk to determine its data format,
          # QCOW for example. If the disk format is not flat, push a disk
          # supporting the format on top of this disk. Then set bfh to point
          # to the new top disk.
          #
          bfh = bfh.pushFormatSupport
        end
      end
      unless bfh
        bfh = MiqDisk.getDisk(dInfo)
      end
      bfh
    end
  end

  def header
    @header ||= begin
      file_handle.seek(0, IO::SEEK_SET)
      partial_header = QCOW_HEADER_PARTIAL.decode(file_handle.read(SIZEOF_QCOW_HEADER_PARTIAL))

      file_handle.seek(0, IO::SEEK_SET)
      case partial_header['version']
      when 1
        raise "QCOW Version 1 is not supported"
        QCOW_HEADER_V1.decode(file_handle.read(SIZEOF_QCOW_HEADER_V1))
      when 2
        h = QCOW_HEADER_V2.decode(file_handle.read(SIZEOF_QCOW_HEADER_V2))
        # TODO: Handle Encryption
        raise "QCOW Encryption is not supported" if h['crypt_method'] == 1
        h
      else
        raise "Uknown Version: #{partial_header['version'].inspect}"
      end
    end
  end

  UINT64 = BinaryStruct.new([
    'N', 'uint64_hi',
    'N', 'uint64_lo',
  ])
  SIZEOF_UINT64 = UINT64.size

  def uint64_from_hi_lo(hi, lo)
    (hi << 32) | lo
  end

  def uint64(h, name)
    uint64_from_hi_lo(h["#{name}_hi"], h["#{name}_lo"])
  end

  def format_entry(e)
    copied     = copied?(e)     ? 'COPIED'     : 'NOT COPIED'
    compressed = compressed?(e) ? 'COMPRESSED' : 'NOT COMPRESSED'
    "#{e} => #{lo62(e)} (#{copied}, #{compressed})"
  end

  def decode_entry(e)
    uint64(UINT64.decode(e), "uint64")
  end

  def get_entry(offset, index)
    pos = offset + (index * SIZEOF_UINT64)
    file_handle.seek(pos, IO::SEEK_SET)
    decode_entry file_handle.read(SIZEOF_UINT64)
  end

  def lo62(x)
    x & LO62_MASK
  end

  def lo63(x)
    x & LO63_MASK
  end

  def copied_mask
    @copied_mask ||= begin
      case version
      when 1
        0
      when 2
        1 << 63
      else
        raise "Unknown QCOW Version: #{version}"
      end
    end
  end

  def compressed_mask
    @compressed_mask ||= begin
      case version
      when 1
        1 << 63
      when 2
        1 << 62
      else
        raise "Unknown QCOW Version: #{version}"
      end
    end
  end

  def compressed?(cluster_offset)
    (cluster_offset & compressed_mask) > 0
  end

  def copied?(cluster_offset)
    (cluster_offset & copied_mask) > 0
  end

  def count_contiguous_clusters(nb_clusters, cluster_size, l2_table, l2_index, start = 0)
    offset = lo63(l2_table[l2_index])

    return 0 if offset.zero?

    count = start
    while count < (start + nb_clusters)
      break if (offset + (count * cluster_size)) != lo63(l2_table[l2_index+count])
      count += 1
    end

    return (count - start)
  end

  def count_contiguous_free_clusters(nb_clusters, l2_table, l2_index)
    count = 0

    while nb_cluster > 0
      break if l2_table[l2_index+count] != 0
      count      += 1
      nb_cluster -= 1
    end

    count
  end

  def csize_shift
    @csize_shift ||= begin
      case version
      when 1
        63 - cluster_bits
      when 2
        62 - (cluster_bits - 8)
      else
        raise "Unknown QCOW Version: #{version}"
      end
    end
  end

  def csize_mask
    @csize_mask ||= (1 << (cluster_bits - 8)) - 1
  end

  def cluster_offset_mask
    @cluster_offset_mask ||= (1 << csize_shift) - 1
  end

  def dump
    out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
    out << "Version                  : #{version}\n"
    out << "Image Size               : #{size}\n"
    out << "Backing File Name        : #{backing_file_name}\n"
    out << "Backing File Name Offset : #{backing_filename_offset}\n"
    out << "Backing File Name Size   : #{backing_filename_size}\n"
    out << "Cluster Bits             : #{cluster_bits}\n"
    out << "Cluster Size             : #{cluster_size}\n"
    out << "Cluster Sectors          : #{cluster_sectors}\n"
    out << "L1 Table Bits            : #{l1_bits}\n"
    out << "L1 Table Size            : #{l1_size}\n"
    out << "L1 Table Size Minimum    : #{l1_size_minimum}\n"
    out << "L1 Table Offset          : #{l1_table_offset}\n"
    out << "L2 Table Bits            : #{l2_bits}\n"
    out << "L2 Table Size            : #{l2_size}\n"
    out << "Crypt Method             : #{crypt_method}\n"
    out << "Snapshot Count           : #{snapshots_count}\n"
    out << "Snapshot Offset          : #{snapshots_offset}\n"
    out << "RefCount Table Offset    : #{refcount_table_offset}\n"
    out << "RefCount Table Clusters  : #{refcount_table_clusters}\n"
    return out
  end

end
