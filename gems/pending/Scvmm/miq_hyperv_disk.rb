$LOAD_PATH.push("#{File.dirname(__FILE__)}/../util")

require 'miq_winrm'
require 'miq_scvmm_parse_powershell'
require 'base64'
require 'securerandom'
require 'memory_buffer'

require 'rufus/lru'

class MiqHyperVDisk

  MIN_SECTORS_TO_CACHE = 16
  DEF_BLOCK_CACHE_SIZE = 200

  attr_reader :hostname, :virtual_disk, :file_offset, :file_size, :parser, :vm_name, :temp_snapshot_name

  def initialize(hyperv_host, user, pass, port = nil)
    @hostname  = hyperv_host
    @winrm     = MiqWinRM.new
    port ||= 5985
    options = {:port     => port,
               :user     => user,
               :pass     => pass,
               :hostname => @hostname
              }
    @connection  = @winrm.connect(options)
    @parser      = MiqScvmmParsePowershell.new
    @block_size  = 4096
    @file_size   = 0
    @block_cache = LruHash.new(DEF_BLOCK_CACHE_SIZE)
  end

  def open(vm_disk)
    @virtual_disk  = vm_disk
    @file_offset   = 0
    stat_script = <<-STAT_EOL
    (Get-Item "#{@virtual_disk}").length
STAT_EOL
    file_size, _stderr  = @parser.parse_single_powershell_value(@winrm.run_powershell_script(stat_script))
    @file_size          = file_size.to_i
    @end_byte_addr      = @file_size - 1
    # @size_in_blocks     = @file_size / @block_size
    @size_in_blocks     = @file_size / @block_size + 1
    @lba_end            = @size_in_blocks - 1
  end

  def size
    @file_size
  end

  def close
    @file_offset   = 0
    @connection    = nil
    @winrm         = nil
  end

  def seek(offset, whence = IO::SEEK_SET)
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
    return nil if @file_offset >= @file_size
    size = @file_size - @file_offset if (@file_offset + size) > @file_size

    start_sector, start_offset = @file_offset.divmod(@block_size)
    end_sector                 = (@file_offset + size - 1) / @block_size
    number_sectors             = end_sector - start_sector + 1

    read_buf                   = bread_cached(start_sector, number_sectors)
    @file_offset               += size

    read_buf[start_offset, size]
  end

  def bread_cached(start_sector, number_sectors)
    @block_cache.keys.each do |block_range|
      if block_range.include?(start_sector) && block_range.include?(start_sector + number_sectors - 1)
        sector_offset = start_sector - block_range.first
        buffer_offset = sector_offset * @block_size
        length = number_sectors * @block_size
        return @block_cache[block_range][buffer_offset, length]
      end
    end
    sectors_to_read           = [MIN_SECTORS_TO_CACHE, number_sectors].max
    end_sector                = start_sector + sectors_to_read - 1
    block_range               = Range.new(start_sector, end_sector)
    @block_cache[block_range] = bread(start_sector, sectors_to_read)

    sector_offset             = start_sector  - block_range.first
    buffer_offset             = sector_offset * @block_size
    length                    = number_sectors * @block_size

    return @block_cache[block_range][buffer_offset, length]
  end

  def bread(start_sector, number_sectors)
    return nil if start_sector > @lba_end
    number_sectors = @size_in_blocks - start_sector if (start_sector + number_sectors) > @size_in_blocks
    read_script = <<-READ_EOL
$file_stream = [System.IO.File]::Open("#{@virtual_disk}", "Open", "Read", "Read")
$buffer      = New-Object System.Byte[] #{number_sectors * @block_size}
$file_stream.seek(#{start_sector * @block_size}, 0)
$file_stream.read($buffer, 0, #{number_sectors * @block_size})
[System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($buffer))
$file_stream.Close()
READ_EOL

    # TODO: Error Handling
    encoded_data = @parser.output_to_attribute(@winrm.run_powershell_script(read_script))
    buffer       = MemoryBuffer.create(@block_size * number_sectors)
    buffer       = ""
    Base64.decode64(encoded_data).split(' ').each { |c| buffer += c.to_i.chr }
    buffer
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
end
