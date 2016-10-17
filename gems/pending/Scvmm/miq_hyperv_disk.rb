# encoding: US-ASCII

require 'util/miq_winrm'
require 'Scvmm/miq_scvmm_parse_powershell'
require 'base64'
require 'securerandom'
require 'memory_buffer'

require 'rufus/lru'

class MiqHyperVDisk
  MIN_SECTORS_TO_CACHE = 64
  DEF_BLOCK_CACHE_SIZE = 1200
  DEBUG_CACHE_STATS    = false
  BREAD_RETRIES        = 3
  OPEN_ERRORS          = %w( Exception\ calling At\ line: ).freeze

  attr_reader :hostname, :virtual_disk, :file_offset, :file_size, :parser, :vm_name, :temp_snapshot_name

  def initialize(hyperv_host, user, pass, port = nil, network = false)
    @hostname  = hyperv_host
    @winrm     = MiqWinRM.new
    port ||= 5985
    @winrm.connect(:port => port, :user => user, :password => pass, :hostname => @hostname)
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

    unless @network
      open_script = <<-OPEN_EOL
$file_stream   = [System.IO.File]::Open("#{@virtual_disk}", "Open", "Read", "Read")
$file_stream.seek(0, 0)
OPEN_EOL
      @winrm.run_powershell_script(open_script)
    end

    stat_script = <<-STAT_EOL
(Get-Item "#{@virtual_disk}").length
STAT_EOL
    file_size, stderr = @parser.parse_single_powershell_value(run_correct_powershell(stat_script))

    if @network && stderr.include?("RegisterTaskDefinition")
      raise "Unable to obtain virtual disk size for #{vm_disk}. Check Hyper-V Host Domain Credentials"
    end
    OPEN_ERRORS.each { |error| raise "Unable to obtain virtual disk size for #{vm_disk}" if stderr.include?(error) }
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
    unless @network
      close_script = <<-CLOSE_EOL
$file_stream.Close()
CLOSE_EOL
      run_correct_powershell(close_script)
    end
    @winrm.close
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
        # This range overlaps the start of our requested read, but more data is required at the end of the request
        sectors_in_range = block_range.last - start_sector
        length           = sectors_in_range * @block_size
        remaining_blocks = number_sectors - sectors_in_range
        @cache_hits[start_sector] += 1
        # The "+" operator is required rather than "<<" so as not to modify the @block_cache object.
        return @block_cache[block_range][buffer_offset, length] + bread_cached(block_range.last + 1, remaining_blocks)
      elsif block_range.include?(start_sector + number_sectors - 1)
        # This range overlaps the end of our requested read, but more data is required at the start of the request
        sectors_in_range = (start_sector + number_sectors) - block_range.first
        length           = sectors_in_range * @block_size
        remaining_blocks = number_sectors - sectors_in_range
        @cache_hits[start_sector] += 1
        # The  "<<" operator is valid and more efficient here
        return bread_cached(start_sector, remaining_blocks) << @block_cache[block_range][0, length]
      elsif block_range.first > start_sector && block_range.last < start_sector + number_sectors
        # This range overlaps our requested read but more data is required both before and after the range
        sectors_in_range   = block_range.last - block_range.first + 1
        sectors_pre_range  = block_range.first - start_sector
        sectors_post_range = number_sectors - sectors_in_range - sectors_pre_range
        # Note the mixed use of operators below.
        # The first "<<" operator is valid and more efficient while the second "+" operator 
        # is required instead so as not to modify the in-place @block_cache object.
        return bread_cached(start_sector, sectors_pre_range) <<
               @block_cache[block_range] +
               bread_cached(block_range.last + 1, sectors_post_range)
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
    read_script    = if @network

                       <<-READ_NETWORK_EOL
$file_stream   = [System.IO.File]::Open("#{@virtual_disk}", "Open", "Read", "Read")
$bufsize       = #{number_sectors * @block_size}
$buffer        = New-Object System.Byte[] $bufsize
$encodedbuflen = $bufsize * 4 / 3
if (($encodedbuflen % 4) -ne 0)
{
$encodedbuflen += 4 - ($encodedbuflen % 4)
}
$encodedarray = New-Object Char[] $encodedbuflen
$file_stream.seek(#{start_sector * @block_size}, 0)
$file_stream.read($buffer, 0, #{expected_bytes})
[System.Convert]::ToBase64CharArray($buffer, 0, $bufsize, $encodedarray, 0)
[string]::join("", $encodedarray)
$file_stream.Close()
READ_NETWORK_EOL
                     else

                       <<-READ_EOL
if ($bufsize -ne #{number_sectors * @block_size})
{
  $bufsize       = #{number_sectors * @block_size}
  $buffer        = New-Object System.Byte[] $bufsize
  $encodedbuflen = $bufsize * 4 / 3
  if (($encodedbuflen % 4) -ne 0)
  {
    $encodedbuflen += 4 - ($encodedbuflen % 4)
  }
  $encodedarray = New-Object Char[] $encodedbuflen
}
$file_stream.seek(#{start_sector * @block_size}, 0)
$file_stream.read($buffer, 0, #{expected_bytes})
[System.Convert]::ToBase64CharArray($buffer, 0, $bufsize, $encodedarray, 0)
[string]::join("", $encodedarray)
READ_EOL
                     end

    i = 0
    (0...BREAD_RETRIES).each do
      t1           = Time.now.getlocal
      encoded_data = @parser.output_to_attribute(run_correct_powershell(read_script))
      if encoded_data.empty?
        $log.debug "#{log_header} no encoded data returned on attempt #{i}"
        i += 1
        continue
      end
      t2           = Time.now.getlocal
      decoded_data = Base64.decode64(encoded_data)
      @total_copy_from_remote_time += t2 - t1
      @total_read_execution_time += Time.now.getlocal - t1
      decoded_size = decoded_data.size
      return decoded_data if expected_bytes == decoded_size
      $log.debug "#{log_header} expected #{expected_bytes} bytes - got #{decoded_size} on attempt #{i}"
      i += 1
    end
    raise "#{log_header} expected #{expected_bytes} bytes - got #{decoded_size}"
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
    # Cache entries are *multiples* of MIN_SECTORS_TO_CACHE * @blocksize  in length,
    # aligned to MIN_SECTORS_TO_CACHE * @blocksize byte boundaries.
    # real_start_block is the aligned cache block based on the start_sector, and
    # real_start_sector is the disk sector for that cache block.
    real_start_block    = start_sector / MIN_SECTORS_TO_CACHE
    real_end_block      = (start_sector + number_sectors) / MIN_SECTORS_TO_CACHE
    number_cache_blocks = real_end_block - real_start_block + 1
    sectors_to_read     = number_cache_blocks * MIN_SECTORS_TO_CACHE
    real_start_sector   = real_start_block * MIN_SECTORS_TO_CACHE
    end_sector          = real_start_sector + sectors_to_read - 1
    Range.new(real_start_sector, end_sector)
  end
end
