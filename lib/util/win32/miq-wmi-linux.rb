$:.push("#{File.dirname(__FILE__)}/..")
require 'miq-hash_struct'
require 'open3'

module WmiLinux

	def connectServer()
		# Connect to WMI
    #self.getObject('Win32_ComputerSystem')
	end

  def logon_username()
    return nil if @username.nil?

    # Check for usernames that supplied the domain as well
    # Example manageiq\user1 or just user1
    if @username.include?("\\")
      domain, name = @username.split("\\")
      return "#{domain}/#{name}"
    end

    # If we just have a username append the server name to it.  Otherwise
    # connecting will fail when running in SYSTEM context.
    return "#{@server}/#{@username}"
  end

  def release
    #NOP
  end

  def verify_credentials()
    getObject('Win32_ComputerSystem')
    true
  end

	def getWin32Service(svcName)
		wmi_object = run_query("select * from Win32_Service where Name = '#{svcName}'")
		wmi_object.each {|s| yield s} if block_given?
    return wmi_object
		# Example calls against the service object.
		#  puts s.started
		#  s.StartService
	end

  def getObject(klassName)
    wmi_object = run_query("select * from #{klassName}")
    wmi_object.each {|w| yield(w)} if block_given?
    return wmi_object
  end

  # Example of using winexe.  Likely will not uses because it relies on a remote installed service
  def get_windows_version()
    stdout_text = ""
    stderr_text = ""
    command_line = "winexe -U #{@server}/#{@username} //#{@server} \"cmd\""
    Open3.popen3(command_line) do |stdin, stdout, stderr|
      Thread.new {loop {x = stderr.gets; stderr_text << x}} #; puts "Err stream:    #{x}"
      Thread.new {loop {y = stdout.gets; stdout_text << y}} #; puts "Output stream: [#{y.class}] #{y}"
      sleep(0.5)
      stdin.puts @password
      loop  {break unless stdout_text.empty? && stderr_text.empty?; sleep(0.1)}
      stdin.puts 'exit'
      sleep(0.2)
    end

    # Parse string like this: "Microsoft Windows [Version 5.2.3790] (C) Copyright 1985-2003 Microsoft Corp."
    return version = stdout_text.split('\n').first.split('[')[1].split(']')[0].split(' ')[1] unless stdout_text.empty?

    raise stderr_text
  end

  def run_query(wmiQuery)
    command_line = "wmic -U #{self.logon_username()} --namespace=\"#{@namespace}\" //#{@server} \"#{wmiQuery}\""
    stdout_text, stderr_text = "", ""
    Open3.popen3(command_line) do |stdin, stdout, stderr|
      #puts "#{stdin.inspect}:#{stdin.pid} - #{stdout.inspect}:#{stdout.pid} - #{stderr.inspect}:#{stderr.pid}"
      Thread.new {loop {x = stderr.gets; stderr_text << x}} #; puts "Err stream:    #{x}"
      Thread.new {loop {y = stdout.gets; stdout_text << y}} #; puts "Output stream: [#{y.class}] #{y}"
      sleep(0.1)
      #puts "Sending Password"
      stdin.puts @password
      loop  {break unless stdout_text.empty? && stderr_text.empty?; sleep(0.1)}
      sleep(1)
    end

    lines = stdout_text.collect {|l| l}
    raise lines.last unless lines[0].include?('CLASS: ')

    wmi_class_name = lines[0].split(": ").last.strip
    wmi_object = []
    col_names = lines[1].split('|').collect {|n| n.strip.to_sym}
    lines[2..-1].each do |data|
      x = {}
      i = 0
      values = data.split('|').collect {|v| v}
      self.value_fixup(wmi_class_name, values, col_names) if values.length > col_names.length
      values.each do |value|
        x[col_names[i]] = value
        i+=1
      end
      # Return HashStruct object so you reference object properties the same as from 'win32ole' objects.
      wmi_object << MiqHashStruct.new(x)
    end

    wmi_object.each {|s| yield s} if block_given?
    return wmi_object
  end

  #TODO: Add support for a get method through Linux
  # Call the 'Get' method when you have a __RELPATH or __PATH string to an object
  # Example: \\DEV008-HYPERV\root\CIMV2:Win32_ComputerSystem.Name="DEV008-HYPERV"
  #       or Win32_ComputerSystem.Name="DEV008-HYPERV"  
  #def get(path)
  #  @objWMI.Get(path)
  #end

  def associators_of(obj, assocClass = nil)
    wql = "ASSOCIATORS OF {#{obj.PATH__}}"
    wql += " WHERE AssocClass = #{assocClass}" unless assocClass.nil?
    wmi_object = run_query(wql)
    wmi_object.each {|s| yield s} if block_given?
    return wmi_object
  end

  def references_of(obj, resultClass = nil)
    wql = "REFERENCES OF {#{obj.PATH__}}"
    wql += " WHERE ResultClass = #{resultClass}" unless resultClass.nil?
    wmi_object = run_query(wql)
    wmi_object.each {|s| yield s} if block_given?
    return wmi_object
  end

  # This method is designed to fixup columns that use the '|' system in the data which is also
  # the separator used by the linux wmic program.
  def value_fixup(wmi_class_name, values, col_names)
    fixup_column_name = case wmi_class_name
    when "Win32_Process" then :OSName
    when "Win32_OperatingSystem" then :Name
    else nil
    end
    idx = 0
    col_names.each {|c| values[idx] += "|#{values.delete_at(idx+1)}|#{values.delete_at(idx+1)}" if c == fixup_column_name; idx+=1} unless fixup_column_name.nil?
  end

  def to_h(instance, nh = {}, paths = {}, level = -2)
    return instance
  end

  def get_instance(wmiQuery)
    wmi_object = nil
    run_query(wmiQuery) {|w| wmi_object = w; break}
    return wmi_object
  end
end
