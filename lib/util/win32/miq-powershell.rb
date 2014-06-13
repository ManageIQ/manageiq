$:.push("#{File.dirname(__FILE__)}/..")
require 'miq-xml'
require 'miq-logger'
require 'runcmd'
require 'io/wait'
require 'open-uri'
require 'miq-encode'
require 'miq-unicode'
require 'win32/registry' if Platform::OS == :win32

module MiqPowerShell
  @@default_port = 9121

  def self.is_available?
    self.exepath
    return true
  rescue
    return false
  end

  def self.exepath
    path = nil
    Win32::Registry::HKEY_LOCAL_MACHINE.open('SOFTWARE\\Microsoft\\PowerShell\\1\\ShellIds\\Microsoft.PowerShell') {|reg| path = reg['Path']}
    path_64 = path.downcase.gsub('syswow64', 'sysnative')
    return path_64 if File.exist?(path_64)
    return path
  end

  def self.execute(ps_command)
    self.validate_version()
    ps_exec = self.exepath()
    command = "start /wait cmd /c #{ps_exec} #{ps_command}"
    $log.debug "PowerShell: Running command: [#{command}]" if $log
    ret = MiqUtil.runcmd(command).chomp
    $log.debug "PowerShell: Return from command: [#{ret}]" if $log
    return ret
  end

  def self.execute_async(ps_command)
    self.validate_version()
    require 'miq-wmi'
    command = "powershell.exe #{ps_command}"
    $log.debug "PowerShell: Running command: [#{command}]" if $log
    wmi = WMIHelper.connectServer()
    pid = wmi.runProcess(command, true, {:ShowWindow=>2})
    $log.debug "PowerShell: Process started with pid: [#{pid}]" if $log
    return pid
  end

  def self.kill_process(pid)
    command = "taskkill /PID #{pid} /F"
    $log.debug "PowerShell: kill_process: [#{command}]" if $log
    ret = MiqUtil.runcmd(command).chomp
    $log.debug "PowerShell: Return from command: [#{ret}]" if $log
    return ret
  end

  def self.validate_version()
    ps = self.version
    $log.debug "Powershell version [#{ps[:RuntimeVersion]}] detected." if $log
    raise "PowerShell Version:[#{ps[:PowerShellVersion]}] (Runtime Version:[#{ps[:RuntimeVersion]}]) is not supported.  Upgrade to v2.0 or greater." if ps[:PowerShellVersion] < 1.1
  end

  def self.version
    ps = {}
    Win32::Registry::HKEY_LOCAL_MACHINE.open('SOFTWARE\\Microsoft\\PowerShell\\1\\PowerShellEngine') do |reg|
      reg.each {|subkey, type, data| ps[subkey.to_sym] = data}
    end
    ps[:PowerShellVersion] = ps[:PowerShellVersion].to_f unless ps[:PowerShellVersion].nil?
    return ps
  end

  def self.verify_return_object(xml)
    return unless is_error_object?(xml)
    err_msg = "#{self.name} "
    node = xml.find_first("//*/Property[@Name=\"FullyQualifiedErrorId\"]")
    err_msg << "(#{node.text}): " unless node.nil?
    node = xml.find_first("//*/Property[@Name=\"ErrorRecord\"]")
    node = xml.find_first("//*/Property[@Name=\"Message\"]") if node.nil? || node.text.to_s.strip.empty?
    err_msg << "#{node.text} " unless node.nil?
    node = xml.find_first("//*/Property[@Name=\"PositionMessage\"]")
    err_msg << "#{node.text}" unless node.nil?
    raise err_msg
  end

  def self.is_error_object?(xml)
    object_type = xml.root.elements[1].attributes['Type'] rescue ""
    return true if !object_type.nil? && object_type.split('.').last == 'ErrorRecord'
    return false
  end

  def self.run_script(script)
    encoded_command = MIQEncode.encode(script.AsciiToUtf8.Utf8ToUnicode, false)
    ps_command = "-EncodedCommand #{encoded_command}"
    self.execute(ps_command)
  end

  def self.pipe_to_xml(filename=nil)
    self.pipe_to_clixml_local + self.clear_local_ps_varialbes + <<-PS_SCRIPT
      $miq_clixml_export_data = Get-Content $miq_clixml_export_filename
      Remove-Item $miq_clixml_export_filename
      $miq_clixml_export_data
    PS_SCRIPT
  end

  def self.pipe_to_xml_path(filename=nil)
    self.pipe_to_clixml_local + self.clear_local_ps_varialbes + <<-PS_SCRIPT
      $miq_clixml_export_filename
    PS_SCRIPT
  end

  def self.pipe_to_clixml
    <<-PS_SCRIPT
 | export-clixml -Encoding UTF8 -Path ($miq_clixml_export_filename = &{
          $tmp_path = [System.IO.Path]::GetTempPath()
          if (!(Test-Path -path $tmp_path)) {New-Item -Path $tmp_path -type directory | Out-Null}
          return [System.IO.Path]::GetTempFileName()
      })
      miq_logger "info" "XML output written to: $($miq_clixml_export_filename)"
    PS_SCRIPT
  end

  def self.pipe_to_clixml_local
    data_file_path = self.get_xml_temp_file.gsub('/', '\\')

    <<-PS_SCRIPT
 | export-clixml -Encoding UTF8 -Path ($miq_clixml_export_filename = '#{data_file_path}')
      miq_logger "info" "XML output written to: $($miq_clixml_export_filename)"
    PS_SCRIPT
  end

  def self.get_xml_temp_file
    require 'tempfile'
    tmp_args = ['psd']
    tmp_args << $miqHostCfg.dataDir if $miqHostCfg
    data_file = Tempfile.new(*tmp_args)
    data_file_path = data_file.path
    data_file.close!
    data_file_path
  end

  def self.get_xml_directory
    File.dirname(get_xml_temp_file)
  end

  def self.clear_orphaned_data_files
    Dir.glob(File.join(get_xml_directory, "psd*.*")).each do |psd_file|
      if File.file?(psd_file)
        $log.warn "MiqPowerShell removing orphaned temp data file <#{psd_file}>" if $log
        File.delete(psd_file)
      end
    end
  end

  def self.clear_local_ps_varialbes
    <<-PS_SCRIPT
      log_memory "info" "Start post-processing"
    PS_SCRIPT
    # <<-PS_SCRIPT
    #   log_memory "info" "Start post-processing"
    #   $miq_global_variable_list = @()
    #   Get-Variable -Scope Global | ForEach-Object {$miq_global_variable_list += $_.Name }
    #   Get-Variable -Scope Local  -Exclude @("_","this","miq_*") | Where-Object {$miq_global_variable_list -inotcontains $_.Name} | foreach {
    #     miq_logger "debug" "Removing Variable: $($_.Name)"
    #     $_ | Remove-Variable -Scope Local -ErrorAction SilentlyContinue
    #   }
    #   Remove-Variable -Name "miq_global_variable_list" -Scope Local
    #   [System.GC]::Collect()
    #   Start-Sleep 0.5
    #   log_memory "debug" "End post-processing"
    # PS_SCRIPT
  end

  def self.ps_xml_to_hash(xml)
    MiqPowerShell::Convert.new(xml).to_h
  end

  def self.log_messages(log_msgs)
    log_msgs.each do |lh|
      log_level = case lh[:level].to_s[0,1].to_s.downcase
      when 'd' then :debug
      when 'w' then :warn
      when 'e' then :error
      when 'f' then :fatal
      else :info
      end
      $log.send(log_level, "Powershell[#{lh[:date]}] #{lh[:msg]}")
    end
  end


  class Convert
    def initialize(xml)
      @refIds = []
      if xml.kind_of?(String)
        @xml = MiqXml.load(xml)
      else
        @xml = xml
      end
    end

    def to_h(options={})
      process_root(@xml.root)
    end

    def to_xml
      @xml
    end

    def process_root(node)
      lst = []
      node.each_element {|e| add_to_array(e, lst)}
      return lst
    end

    def process_array(node)
      lst = []
      node.each_element {|e| add_to_array(e, lst)}
      return lst
    end

    def process_hash(node)
      hsh = {}
      node.each_element do |e|
        name = convert_type(e.elements[1])
        name = name.to_sym if name.is_a?(String)
        data = e.elements[2]

        case data.name
        when 'Obj' then hsh[name] = process_obj(data)
        when 'Ref' then hsh[name] = @refIds[data.attributes['RefId'].to_i]
        else hsh[name] = convert_type(data)
        end
      end
      return hsh
    end

    def process_named_elements(node)
      hsh = {}
      node.each_element do |e|
        name = e.attributes['N']
        name = e.name if name.nil?
        name = name.to_sym

        case e.name
        when 'Obj' then hsh[name] = process_obj(e)
        when 'Ref' then hsh[name] = @refIds[e.attributes['RefId'].to_i]
        when 'Props' then hsh[:Props] = process_named_elements(e)
        when 'MS'    then hsh[:MS]    = process_named_elements(e)
        when 'TNRef' then nil
        when 'TN' then nil
        else hsh[name] = convert_type(e)
        end
      end
      return hsh
    end

    def process_obj(node)
      lst = node.elements['LST']
      dct = node.elements['DCT']
      refId = node.attributes['RefId'].to_i

      obj = nil
      if lst.nil? && dct.nil?
        obj = process_named_elements(node)
      elsif lst
        obj = process_array(lst)
      elsif dct
        obj = process_hash(dct)
      end

      # Store refId
      @refIds[refId] = obj unless refId.nil?
      return obj
    end

    def add_to_array(node, lst)
      case node.name
      when 'TN' then return
      when 'Obj' then lst << process_obj(node)
      when 'Ref' then lst << @refIds[node.attributes['RefId'].to_i]
      else lst << convert_type(node)
      end
    end

    def convert_type(c)
      case c.name.to_sym
      when :U16, :U32, :I32, :U64, :I64, :D, :By then c.text.to_i
      when :Db then c.text.to_f
      when :B then c.text.downcase == 'true'
      when :S, :Version, :G, :Ref then c.text.chomp unless c.text.nil?
      when :DT
        c_text = c.text
        if /\d+-\d+-\d+T\d+:\d+:\d+.\d+(.*)/ =~ c_text
          c_text += "Z" if $1.length == 0
        end
        Time.parse(c_text)
      when :Nil then nil
      else c.text.to_s.chomp
      end
    end
  end

  #class Error < RuntimeError
  #  attr_reader :exception, :category, :target_object, :details
  #  def initialize(exception, category, target_object, details)
  #    @exception = exception
  #    @category  = category
  #    @target    = target_object
  #    @details   = details
  #  end
  #
  #  def to_s
  #    return @exception unless @exception.nil?
  #    return @details
  #  end
  #
  #  def self.from_xml(node)
  #    eh = {}
  #    node.root.elements[1].each_element {|e| eh[e.attributes['Name']] = e.text}
  #    return self.new(eh['Exception'], eh['CategoryInfo'], eh['TargetObject'], eh['ErrorDetails'])
  #  end
  #
  #  def self.is_error_object?(xml)
  #    object_type = xml.root.elements[1].attributes['Type'] rescue ""
  #    return true if !object_type.nil? && object_type.split('.').last == 'ErrorRecord'
  #    return false
  #  end
  #end
end
