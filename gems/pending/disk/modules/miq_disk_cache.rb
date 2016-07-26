require 'rufus/lru'
require_relative "../MiqDisk"
require 'ostruct'

module MiqDiskCache
  MIN_SECTORS_PER_ENTRY = 32
  DEF_LRU_HASH_ENTRIES = 100
  DEBUG_CACHE_STATS    = false

  attr_reader :d_size, :blockSize, :lru_hash_entries, :min_sectors_per_entry, :cache_hits, :cache_misses

  def self.new(up_stream, lru_hash_entries = DEF_LRU_HASH_ENTRIES, min_sectors_per_entry = MIN_SECTORS_PER_ENTRY)
    raise "MiqDiskCache: Downstream Disk Module is nil" if up_stream.nil?
    @dInfo                       = OpenStruct.new
    @dInfo.lru_hash_entries      = lru_hash_entries
    @dInfo.min_sectors_per_entry = min_sectors_per_entry
    @dInfo.block_size            = up_stream.blockSize
    @dInfo.up_stream             = up_stream

    MiqDisk.new(self, @dInfo, 0)
  end

  def d_init
    @block_cache           = LruHash.new(@dInfo.lru_hash_entries)
    @cache_hits            = Hash.new(0)
    @cache_misses          = Hash.new(0)
    @blockSize             = @dInfo.block_size
    @up_stream             = @dInfo.up_stream
    @min_sectors_per_entry = @dInfo.min_sectors_per_entry
  end

  def d_size
    @d_size ||= @up_stream.d_size
  end

  def dInfo
    @up_stream.dInfo
  end

  def d_read(pos, len)
    $log.debug "MiqDiskCache.d_read(#{pos}, #{len})"
    return nil if pos >= @endByteAddr
    len = @endByteAddr - pos if (pos + len) > @endByteAddr
    start_sector, start_offset = pos.divmod(@blockSize)
    end_sector                 = (pos + len - 1) / @blockSize
    number_sectors             = end_sector - start_sector + 1
    d_read_cached(start_sector, number_sectors)[start_offset, len]
  end

  def d_read_cached(start_sector, number_sectors)
    $log.debug "MiqDiskCache.d_read_cached(#{start_sector}, #{number_sectors})"
    @block_cache.keys.each do |block_range|
      sector_offset = start_sector - block_range.first
      buffer_offset = sector_offset * @blockSize
      if block_range.include?(start_sector) && block_range.include?(start_sector + number_sectors - 1)
        length = number_sectors * @blockSize
        @cache_hits[start_sector] += 1
        return @block_cache[block_range][buffer_offset, length]
      elsif block_range.include?(start_sector)
        # This range overlaps the start of our requested reqd, but more data is required at the end of the request
        sectors_in_range = block_range.last - start_sector
        length           = sectors_in_range * @blockSize
        remaining_blocks = number_sectors - sectors_in_range
        @cache_hits[start_sector] += 1
        # The "+" operator is required rather than "<<" so as not to modify the @block_cache object
        return @block_cache[block_range][buffer_offset, length] + d_read_cached(block_range.last + 1, remaining_blocks)
      elsif block_range.include?(start_sector + number_sectors - 1)
        # This range overlaps the end of our requested read, but more data is required at the start of the request
        sectors_in_range = (start_sector + number_sectors) - block_range.first
        length           = sectors_in_range * @blockSize
        remaining_blocks = number_sectors - sectors_in_range
        @cache_hits[start_sector] += 1
        # The "<<" operator is valid and more efficient here
        return d_read_cached(start_sector, remaining_blocks) << @block_cache[block_range][0, length]
      elsif block_range.first > start_sector && block_range.last < start_sector + number_sectors
        # This range overlaps our requested read but more data is required both before and after the range
        sectors_in_range   = block_range.last - block_range.first + 1
        sectors_pre_range  = block_range.first - start_sector
        sectors_post_range = number_sectors - sectors_in_range - sectors_pre_range
        # Note the mixed use of operators below.
        # The first "<<" operator is valid and more efficient while the second "+" operator
        # is required instead so as not to modify the in-place @block_cache object.
        return d_read_cached(start_sector, sectors_pre_range) <<
               @block_cache[block_range] +
               d_read_cached(block_range.last + 1, sectors_post_range)
      end
    end
    block_range               = entry_range(start_sector, number_sectors)
    range_length              = (block_range.last - block_range.first + 1) * @blockSize
    @block_cache[block_range] = @up_stream.d_read(block_range.first * @blockSize, range_length)
    @cache_misses[start_sector] += 1

    sector_offset = start_sector - block_range.first
    buffer_offset = sector_offset * @blockSize
    length        = number_sectors * @blockSize

    @block_cache[block_range][buffer_offset, length]
  end

  def d_close
    hit_or_miss if DEBUG_CACHE_STATS
    @up_stream.d_close
  end

  def method_missing(m, *args)
    @up_stream.send(m, *args)
  end

  def respond_to_missing(_method_name, _include_private = false)
    true
  end

  private

  def hit_or_miss
    hits   = @cache_hits.values.reduce(:+)
    misses = @cache_misses.values.reduce(:+)
    $log.debug "MiqDiskCache cache hits: #{hits}"
    $log.debug "MiqDiskCache cache misses: #{misses}"
  end

  def entry_range(start_sector, number_sectors)
    # Cache entries are *multiples* of @min_sectors_per_entry * @blocksize  in length,
    # aligned to @min_sectors_per_entry * @blocksize byte boundaries.
    # real_start_block is the aligned cache block based on the start_sector, and
    # real_start_sector is the disk sector for that cache block.
    real_start_block    = start_sector / @min_sectors_per_entry
    real_end_block      = (start_sector + number_sectors) / @min_sectors_per_entry
    number_cache_blocks = real_end_block - real_start_block + 1
    sectors_to_read     = number_cache_blocks * @min_sectors_per_entry
    real_start_sector   = real_start_block * @min_sectors_per_entry
    end_sector          = real_start_sector + sectors_to_read - 1
    Range.new(real_start_sector, end_sector)
  end
end
