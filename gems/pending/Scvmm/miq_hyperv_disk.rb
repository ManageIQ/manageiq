$:.push("#{File.dirname(__FILE__)}/../util")

require 'miq_winrm'
require 'miq_scvmm_parse_powershell'
require 'base64'

class MiqHyperVDisk
  attr_reader :hostname, :virtual_disk, :file_offset

  def initialize(hyperv_host, user, pass, port = nil)
    @hostname  = hyperv_host
    @winrm     = MiqWinRM.new
    port       ||= 5985
    options    = {:port     => port,
                  :user     => user,
                  :pass     => pass,
                  :hostname => @hostname
                 }
    @connection = @winrm.connect(options)
  end

  def open(vm_disk)
    @virtual_disk = vm_disk
    @file_offset   = 0
  end

  def seek(offset)
    @file_offset = offset
  end

  def read(size)
    read_script = <<-READ_EOL
$file_stream = [System.IO.File]::Open("#{@virtual_disk}", "Open")
$buffer      = New-Object System.Byte[] #{size}
$file_stream.seek(#{@file_offset}, 0)
$file_stream.read($buffer, 0, #{size})
[System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($buffer))
READ_EOL

    # TODO: Error Handling
    parser = MiqScvmmParsePowershell.new
    encoded_data = parser.output_to_attribute(@winrm.run_powershell_script(read_script))
    # TODO: If size > EOF offset should be at EOF.
    @file_offset += size
    Base64.decode64(encoded_data)
  end
end
