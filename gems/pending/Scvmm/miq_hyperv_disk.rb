$LOAD_PATH.push("#{File.dirname(__FILE__)}/../util")

require 'miq_winrm'
require 'miq_scvmm_parse_powershell'
require 'base64'
require 'securerandom'

class MiqHyperVDisk
  attr_reader :hostname, :virtual_disk, :file_offset, :parser, :vm_name, :temp_snapshot_name

  def initialize(hyperv_host, user, pass, port = nil)
    @hostname  = hyperv_host
    @winrm     = MiqWinRM.new
    port ||= 5985
    options = {:port     => port,
               :user     => user,
               :pass     => pass,
               :hostname => @hostname
              }
    @connection = @winrm.connect(options)
    @parser     = MiqScvmmParsePowershell.new
  end

  def open(vm_disk)
    @virtual_disk  = vm_disk
    @file_offset   = 0
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
      # TODO: Get Filesize from Windows and save offset from EOF here.
      # @file_offset = @endByteAddr + offset
    when IO::SEEK_SET
      @file_offset = offset
    end
    @file_offset
  end

  def read(size)
    read_script = <<-READ_EOL
$file_stream = [System.IO.File]::Open("#{@virtual_disk}", "Open")
$buffer      = New-Object System.Byte[] #{size}
$file_stream.seek(#{@file_offset}, 0)
$file_stream.read($buffer, 0, #{size})
[System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($buffer))
$file_stream.Close()
READ_EOL

    # TODO: Error Handling
    encoded_data = @parser.output_to_attribute(@winrm.run_powershell_script(read_script))
    # TODO: If size > EOF offset should be at EOF.
    @file_offset += size
    temp_buf     = ""
    Base64.decode64(encoded_data).split(' ').each { |c| temp_buf += c.to_i.chr }
    temp_buf
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
