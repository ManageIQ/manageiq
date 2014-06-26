# IPMI - Intelligent Platform Management Interface
# IPMI Tools man page
# http://ipmitool.sourceforge.net/manpage.html

# This utility relies on the following Linux packages
#   OpenIPMI-tools.x86_64
#   freeipmi.x86_64

require 'runcmd'
require 'miq-extensions'

class MiqIPMI
  def initialize(server=nil, username=nil, password=nil)
    @server = server
    @username = username
    @password = password
    @status = self.chassis_status rescue nil
    @vendor = nil
  end

  def connected?
    !@status.nil?
  end

  def power_state
    result = run_command("chassis power status")
    result.split(" ").last
  end

  def power_on
    run_command("chassis power on")
  end

  def power_off
    run_command("chassis power off")
  end

  def power_reset
    if self.power_state == "off"
      self.power_on
    else
      self.power_state_change('reset')
    end
  end

  def power_state_change(new_state)
    #status, on, off, cycle, reset, diag, soft
    run_command("chassis power #{new_state}")
  end

  def chassis_status
    parse_key_value("chassis status")
  end

  def lan_info
    parse_key_value("lan print")
  end

  def mc_info
    parse_key_value("mc info")
  end

  def manufacturer
    self.mc_info['Manufacturer Name']
  end

  def model
    # This method tries to return the model of the device, but depending on what inforamtion
    # comes back from the RFU (Field Replaceable Unit) this may not be accurate.
    fru = self.fru_info.first
    return fru["Board Product"] unless fru.blank?
    return nil
  end

  def fru_info
    return @devices unless @devices.nil?

    @devices = []
    dev_id = nil
    dev_descript = nil
    dev_lines = nil
    cmd_output = run_command("fru print", true)
    cmd_output.each_line do |line|
      if line =~ /^FRU Device Description : (.*) \(ID (\d+)\)/i
        @devices << fru_process_info(dev_id, dev_descript, dev_lines) unless dev_lines.nil?
        dev_descript, dev_id, dev_lines = $1, $2, ''
      else
        dev_lines += line unless dev_lines.nil?
      end
    end

    @devices << fru_process_info(dev_id, dev_descript, dev_lines)
    return @devices.compact
  end

  def fru_process_info(id, description, lines)
    dh = nil
    unless lines.blank?
      dh = parse_output(lines)
      dh.merge!("output" => lines) if dh.blank?
      dh.merge!({"ID" => id, "Description" => description})
    end
    return dh
  end

  def mac_address
    macs = self.mac_addresses
    return nil if macs.blank?
    result = macs.detect {|mac| mac[:enabled] == true}
    return result[:address] unless result.nil?
    return nil
  end

  def mac_addresses
    vendor = self.manufacturer.to_s.downcase
    return self.dell_mac_addresses if vendor.include?('dell')
    return nil
  end

  #Sample "delloem mac" output
  #   System LOMs
  #   NIC Number	MAC Address		Status
  #
  #   0		78:2b:cb:00:f6:6c	Enabled
  #   1		78:2b:cb:00:f6:6d	Enabled
  #
  #   iDRAC6 MAC Address 78:2b:cb:00:f6:6e
  #
  def dell_mac_addresses
    macs = []
    result = run_command("delloem mac")
    result.each_line do |line|
      data = line.split(' ')
      if data[0].to_i.to_s == data[0].to_s
        macs << mac = {:index => data[0], :address => data[1]}
        unless data[2].blank?
          mac[:enabled] = data[2] == 'Enabled'
        else
          mac[:enabled] = true
        end
      end
    end
    return macs
  end

  def parse_key_value(ipmi_cmd, continue_on_error=false)
    parse_output(run_command(ipmi_cmd, continue_on_error))
  end

  def parse_output(cmd_text)
    last_key = nil
    lines = cmd_text.kind_of?(Array) ? cmd_text : cmd_text.split("\n")
    lines.inject({}) do |a, line|
      idx = line.index(": ")
      if idx.nil?
        key = nil
        value = line.strip
      else
        key = line[0, idx].strip
        value = line[idx+1..-1].strip
      end
      next(a) if key.blank? && value.blank?

      # Determine if this line has its own key value or not
      if key.blank? && !last_key.blank?
        key = last_key
        a[key] = [a[key]] unless a[key].kind_of?(Array)
      end

      unless key.blank? || value.blank?
        a[key].kind_of?(Array) ? a[key] << value : a[key] = value
      end
      last_key = key
      a
    end
  end

  def run_command(ipmi_cmd, continue_on_error=false)
    # -E: The remote server password is specified by the environment variable IPMI_PASSWORD.
    ENV['IPMI_PASSWORD']=@password
    command_line = "ipmitool -I #{interface_mode} -H #{@server} -U #{@username} -E #{ipmi_cmd}"

    begin
      return MiqUtil.runcmd(command_line)
    rescue => err
      return err.to_s if continue_on_error == true && $?.exitstatus == 1
      raise "Command:<#{command_line}> exited with status:<#{$?.exitstatus}>\nCommand output:\n#{err.to_s}"
    end
  end

  def self.is_available?(ip_address)
    return self.is_any_available?(ip_address)
    #return true if self.is_2_0_available?(ip_address)
    #return true if self.is_1_5_available?(ip_address)
    #false
  end

  def self.is_any_available?(ip_address)
    # One ping reply if machine supports IPMI
    self.is_available_check(ip_address, nil)
  end

  def interface_mode
    @if_mode ||= self.class.is_2_0_available?(@server) ? "lanplus" : "lan"
  end

  def self.is_2_0_available?(ip_address)
    # One ping reply if machine supports IPMI V2.0
    self.is_available_check(ip_address, "2.0")
  end

  def self.is_1_5_available?(ip_address)
    # One ping reply if machine supports IPMI V1.5
    self.is_available_check(ip_address, "1.5")
  end

  def self.is_available_check(ip_address, version=nil)
    begin
      if version.nil?
        MiqUtil.runcmd("ipmiping #{ip_address} -c 1")
      else
        MiqUtil.runcmd("ipmiping #{ip_address} -r #{version} -c 1")
      end
    rescue
      false
    end
  end
end
