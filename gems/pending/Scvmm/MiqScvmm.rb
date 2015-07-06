$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../util/win32")
require 'miq-xml'
require 'miq-powershell'
require 'miq-powershell-daemon'
require 'MiqScvmmVm'
require 'miq-hash_struct'

class MiqScvmm
  attr_reader :connected
  attr_accessor :stdout

  def initialize(server, username, password)
    @server, @username, @password  = server, username, password
    @connected = false
    @psd = nil
    @stdout = $stdout   # Used by druby to redirect stdout to the client process
                        # puts calls become @stdout.puts 'text'
  end

  def connect()
    @psd = MiqPowerShell::Daemon.new()
    @psd.connect

    ps_script = self.ps_cache_server_command() +
    <<-EOL

    #
    # Return SCVMM Server object
    #
    $scvmm['#{@server}']
    EOL
    xml = self.run_command(ps_script, :xml)
    @connected = true
    return xml
  end

  def disconnect()
    if @connected == true
      ps_script = <<-EOL

      #
      # Remove SCVMM Server object
      #
      $scvmm.remove('#{@server}')
      EOL
      self.run_command(ps_script, :string)
    end
    @psd.disconnect unless @psd.nil?
    @connected = false
  end

  def start(uuid)
    ps_script = ps_find_vm_by_uuid(uuid) +
    <<-EOL

    #
    # Start VM
    #
    if ($vm.status -eq 'paused') {Resume-VM $vm}
    ElseIf ($vm.status -ne 'running') {Start-VM $vm}
    $vm
    EOL
    return self.run_command(ps_script, :object)
  end

  def stop(uuid, force=true)
    ps_script = ps_find_vm_by_uuid(uuid) +
    <<-EOL

    #
    # Shutdown or Stop VM
    #
    if ($vm.status -ne 'PowerOff') {
      if ($vm.vmaddition -eq 'detected') {Shutdown-VM $vm} else {Stop-VM $vm}
    }
    $vm
    EOL
    self.run_command(ps_script, :object)
  end

  def shutdownGuest(uuid)
    ps_script = ps_find_vm_by_uuid(uuid) +
    <<-EOL

    #
    # Stop VM
    #
    if ($vm.status -ne 'PowerOff') {Shutdown-VM $vm}
    $vm
    EOL
    self.run_command(ps_script, :object)
  end

  def suspend(uuid)
    ps_script = ps_find_vm_by_uuid(uuid) +
    <<-EOL

    #
    # Suspend VM (SaveState)
    #
    SaveState-VM $vm
    $vm
    EOL
    self.run_command(ps_script, :object)
  end

  def pause(uuid)
    ps_script = ps_find_vm_by_uuid(uuid) +
    <<-EOL

    #
    # Pause VM
    #
    Suspend-VM $vm
    $vm
    EOL
    self.run_command(ps_script, :object)
  end

  def ps_cache_server_command()
    MiqScvmm.ps_cache_server_command(@server, @username, @password)
  end

  def getVm(path)
    local_path = File.uri_to_local_path(path)
    local_path.gsub!("/","\\")
    ps_script = <<-EOL

    #
    # Find VM by Guid
    #
    Get-VM | ForEach-Object {if ($_.vmcpath -eq '#{local_path}') {$vm = $_}}
    $vm
    EOL
    vmh = self.run_command(ps_script, :object)
    ost = MiqHashStruct.new(:vmService => self)
    return MiqScvmmVm.new(ost, vmh)
  end
  
  def get_vm_by_uuid(uuid)
    ps_script = <<-EOL

    #
    # Find VM by Guid
    #
    Get-VM | ForEach-Object {if ($_.vmid -eq '#{uuid}') {$vm = $_}}
    $vm
    EOL
    vmh = self.run_command(ps_script, :object)
    ost = MiqHashStruct.new(:vmService => self)
    return MiqScvmmVm.new(ost, vmh)
  end

  def self.ps_cache_server_command(server, username, password)
    b64_pwd = MIQEncode.encode(password, false).chomp()
    <<-EOL

    #
    # Load SCVMM Server
    #
    Add-PSSnapin Microsoft.SystemCenter.VirtualMachineManager
    if ($scvmm -eq $null) {${GLOBAL:scvmm}=@{}}
    if ($scvmm['#{server}'] -eq $null) {
      write-host 'Loading scvmm server'
      $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('#{b64_pwd}'))
      $cred = New-Object System.Management.Automation.PsCredential #{username}, (convertto-securestring $decoded -asplaintext -force)
      $scvmm['#{server}'] = Get-VMMServer #{server} -credential $cred
    }
    else { write-host 'using cached scvmm server'}
    EOL
  end

  def ps_find_vm_by_uuid(uuid)
    <<-EOL

    #
    # Find VM by Guid
    #
    Get-VM | ForEach-Object {if ($_.vmid -eq '#{uuid}') {$vm = $_}}
    $vm
    EOL
  end

  def run_command(ps_script, return_type=:xml)
    @psd.run_script(ps_script, return_type)
  end

  def isAlive?
    true
  end
end # class MiqScvmm
