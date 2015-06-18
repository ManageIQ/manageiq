$LOAD_PATH.push("#{File.dirname(__FILE__)}/../util")

require 'miq_winrm'
require 'miq_scvmm_parse_powershell'

class MiqScvmmVmSSAInfo
  attr_reader :vhd, :hostname, :checkpoints, :connection, :vhd_type
  def initialize(provider, user, pass, port = nil)
    @checkpoints = []
    @vhd         = nil
    @hostname    = nil
    @vhd_type    = nil
    @winrm       = MiqWinRM.new
    winrmport    = port.nil? ? 5985 : port
    options      = {:port     => winrmport,
                    :user     => user,
                    :pass     => pass,
                    :hostname => provider
                   }

    @connection = @winrm.connect(options)
  end

  def vm_host(vm_name)
    host_script = <<-HOST_EOL
Get-SCVirtualMachine -VMMServer localhost -Name "#{vm_name}" | \
  Select-Object -ExpandProperty Hostname
HOST_EOL

    # TODO: Examine this code for multiple hard drives.
    @hostname = parse_single_powershell_value(@winrm.run_powershell_script(host_script))
  end

  def vm_harddisks(vm_name)
    location_script = <<-LOCATION_EOL
Get-SCVirtualHardDisk -VMMServer localhost -VM "#{vm_name}" | \
  Select-Object -ExpandProperty Location
LOCATION_EOL

    @vhd_type ||= vm_vhdtype(vm_name)
    if @vhd_type == "DynamicallyExpanding"
      @vhd = parse_single_powershell_value(@winrm.run_powershell_script(location_script))
    elsif @vhd_type == "Differencing"
      # TODO: return both the Parent Disk and the Checkpoint Disk
      raise "Currently unsupported VHD Type #{@vhd_type}"
    else
      raise "Currently unsupported VHD Type #{@vhd_type}"
    end
  end

  def vm_vhdtype(vm_name)
    vhdtype_script = <<-VHDTYPE_EOL
Get-SCVirtualHardDisk -VMMServer localhost -VM "#{vm_name}" | \
  Select-Object -ExpandProperty VHDType
VHDTYPE_EOL

    @vhd_type = parse_single_powershell_value(@winrm.run_powershell_script(vhdtype_script))
  end

  private

  def parse_single_powershell_value(output)
    stdout = ""
    output[:data].each do |d|
      stdout << d[:stdout] unless d[:stdout].nil?
    end
    stdout.split("\r\n").first
  end
end
