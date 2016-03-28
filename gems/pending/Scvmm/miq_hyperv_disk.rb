# encoding: US-ASCII

require 'util/miq_winrm'
require 'Scvmm/miq_scvmm_parse_powershell'
require 'base64'
require 'securerandom'
require 'memory_buffer'

require 'rufus/lru'

class MiqHyperVDisk
  MIN_SECTORS_TO_CACHE = 8
  DEF_BLOCK_CACHE_SIZE = 300
  DEBUG_CACHE_STATS    = false
  BREAD_RETRIES        = 3

  attr_reader :hostname, :virtual_disk, :file_offset, :file_size, :parser, :vm_name, :temp_snapshot_name

  def initialize(hyperv_host, user, pass, port = nil, network = nil)
    @hostname  = hyperv_host
    @winrm     = MiqWinRM.new
    port ||= 5985
    @winrm.connect(:port => port, :user => user, :pass => pass, :hostname => @hostname)
    @parser       = MiqScvmmParsePowershell.new
    @block_size   = 4096
    @file_size    = 0
    @block_cache  = LruHash.new(DEF_BLOCK_CACHE_SIZE)
    @cache_hits   = Hash.new(0)
    @cache_misses = Hash.new(0)
    @network      = network
    @total_read_execution_time = @total_copy_from_remote_time = 0
  end

  def open(vm_disk)
    @virtual_disk  = vm_disk
    @file_offset   = 0
    stat_script = <<-STAT_EOL
    (Get-Item "#{@virtual_disk}").length
STAT_EOL
    file_size, stderr = @parser.parse_single_powershell_value(run_correct_powershell(stat_script))
    raise "Unable to obtain virtual disk size for #{vm_disk}" if stderr.include?("At line:")
    @file_size           = file_size.to_i
    @end_byte_addr       = @file_size - 1
    @size_in_blocks, rem = @file_size.divmod(@block_size)
    @size_in_blocks += 1 if rem > 0
    @lba_end = @size_in_blocks - 1
  end

  def size
    @file_size
  end

  def close
    hit_or_miss if DEBUG_CACHE_STATS
    @file_offset = 0
    @winrm = nil
  end

  def hit_or_miss
    $log.debug "\nmiq_hyperv_disk cache hits:"
    @cache_hits.keys.sort.each do |block|
      $log.debug "block #{block} - #{@cache_hits[block]}"
    end
    $log.debug "\nmiq_hyperv_disk cache misses:"
    @cache_misses.keys.sort.each do |block|
      $log.debug "block #{block} - #{@cache_misses[block]}"
    end
    $log.debug "Total time spent copying reads from remote system is #{@total_copy_from_remote_time}"
    $log.debug "Total time spent transferring and decoding reads on local system is #{@total_read_execution_time - @total_copy_from_remote_time}"
    $log.debug "Total time spent processing remote reads is #{@total_read_execution_time}"
  end

  def seek(offset, whence = IO::SEEK_SET)
    $log.debug "miq_hyperv_disk.seek(#{offset})"
    case whence
    when IO::SEEK_CUR
      @file_offset += offset
    when IO::SEEK_END
      @file_offset = @end_byte_addr + offset
    when IO::SEEK_SET
      @file_offset = offset
    end
    @file_offset
  end

  def read(size)
    $log.debug "miq_hyperv_disk.read(#{size})"
    return nil if @file_offset >= @file_size
    size = @file_size - @file_offset if (@file_offset + size) > @file_size

    start_sector, start_offset = @file_offset.divmod(@block_size)
    end_sector                 = (@file_offset + size - 1) / @block_size
    number_sectors             = end_sector - start_sector + 1

    @file_offset += size
    bread_cached(start_sector, number_sectors)[start_offset, size]
  end

  def bread_cached(start_sector, number_sectors)
    $log.debug "miq_hyperv_disk.bread_cached(#{start_sector}, #{number_sectors})"
    @block_cache.keys.each do |block_range|
      sector_offset = start_sector - block_range.first
      buffer_offset = sector_offset * @block_size
      if block_range.include?(start_sector) && block_range.include?(start_sector + number_sectors - 1)
        length = number_sectors * @block_size
        @cache_hits[start_sector] += 1
        return @block_cache[block_range][buffer_offset, length]
      elsif block_range.include?(start_sector)
        sectors_in_range = block_range.last - start_sector
        length           = sectors_in_range * @block_size
        remaining_blocks = number_sectors - sectors_in_range
        @cache_hits[start_sector] += 1
        return @block_cache[block_range][buffer_offset, length] + bread_cached(block_range.last + 1, remaining_blocks)
      elsif block_range.include?(start_sector + number_sectors - 1)
        sectors_in_range = (start_sector + number_sectors) - block_range.first
        length           = sectors_in_range * @block_size
        remaining_blocks = number_sectors - sectors_in_range
        @cache_hits[start_sector] += 1
        return bread_cached(start_sector, remaining_blocks) + @block_cache[block_range][block_range.first, length]
      end
    end
    block_range               = entry_range(start_sector, number_sectors)
    @block_cache[block_range] = bread(block_range.first, block_range.last - block_range.first + 1)
    @cache_misses[start_sector] += 1

    sector_offset             = start_sector - block_range.first
    buffer_offset             = sector_offset * @block_size
    length                    = number_sectors * @block_size

    @block_cache[block_range][buffer_offset, length]
  end

  def bread(start_sector, number_sectors)
    log_header = "MIQ(#{self.class.name}.#{__method__}:"
    $log.debug "#{log_header} (#{start_sector}, #{number_sectors})"
    return nil if start_sector > @lba_end
    number_sectors = @size_in_blocks - start_sector if (start_sector + number_sectors) > @size_in_blocks
    expected_bytes = number_sectors * @block_size
    read_script = <<-READ_EOL
$file_stream = [System.IO.File]::Open("#{@virtual_disk}", "Open", "Read", "Read")
$buffer      = New-Object System.Byte[] #{number_sectors * @block_size}
$file_stream.seek(#{start_sector * @block_size}, 0)
$file_stream.read($buffer, 0, #{expected_bytes})
[System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($buffer))
$file_stream.Close()
READ_EOL

    (0...BREAD_RETRIES).each do
      t1           = Time.now.getlocal
      encoded_data = @parser.output_to_attribute(run_correct_powershell(read_script))
      t2           = Time.now.getlocal
      buffer       = ""
      Base64.decode64(encoded_data).split(' ').each { |c| buffer += c.to_i.chr }
      @total_copy_from_remote_time += t2 - t1
      @total_read_execution_time += Time.now.getlocal - t1
      return buffer if expected_bytes == buffer.size
      $log.debug "#{log_header} expected #{expected_bytes} bytes - got #{buffer.size}"
    end
    raise "#{log_header} expected #{expected_bytes} bytes - got #{buffer.size}"
  end

  def snap(vm_name)
    @vm_name = vm_name
    @temp_snapshot_name = vm_name + SecureRandom.hex
    snap_script = <<-SNAP_EOL
Checkpoint-VM -Name #{@vm_name} -SnapshotName #{@temp_snapshot_name}
SNAP_EOL
    @vm_name = vm_name
    @temp_snapshot_name = vm_name + SecureRandom.hex
    @winrm.run_powershell_script(snap_script)
  end

  def delete_snap
    delete_snap_script = <<-DELETE_SNAP_EOL
Remove-VMSnapShot -VMName #{@vm_name} -Name #{@temp_snapshot_name}
DELETE_SNAP_EOL
    @winrm.run_powershell_script(delete_snap_script)
  end

  private

  def run_correct_powershell(script)
    return @winrm.run_elevated_powershell_script(script) if @network
    @winrm.run_powershell_script(script)
  end

  def entry_range(start_sector, number_sectors)
    real_start_block, sector_offset = start_sector.divmod(MIN_SECTORS_TO_CACHE)
    number_blocks     = number_sectors % MIN_SECTORS_TO_CACHE
    sectors_to_read   = (number_blocks + (sector_offset > 0 ? 1 : 0)) * MIN_SECTORS_TO_CACHE
    real_start_sector = real_start_block * MIN_SECTORS_TO_CACHE
    end_sector        = real_start_sector + sectors_to_read - 1
    Range.new(real_start_sector, end_sector)
  end
end
