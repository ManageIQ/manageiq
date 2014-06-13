module WmiMswin
  require 'win32ole'
  
	def connectServer()
		# Connect to WMI
		WIN32OLE.ole_initialize
		objLocator = WIN32OLE.new("WbemScripting.SWbemLocator")
    begin
      @objWMI=objLocator.ConnectServer(@server, @namespace, self.logon_username(), @password)
    rescue
      # Win2008 and Vista throw an error if you specify credentials
      if $!.to_s.include?('User credentials cannot be used for local connections')
        @objWMI=objLocator.ConnectServer(@server, @namespace, nil, nil)
      else
        raise
      end
    end
		@objWMI.Security_.ImpersonationLevel=3 #Impersonate
	end

  def logon_username()
    return nil if @username.nil?

    # Check for usernames that supplied the domain as well
    # Example manageiq\user1 or just user1
    return @username if @username.include?("\\")

    # If we just have a username append the server name to it.  Otherwise
    # connecting will fail when running in SYSTEM context.
    return "#{@server}\\#{@username}"
  end

  def release
    unless @objWMI.nil?
      @objWMI.ole_free rescue nil
    end
  end

  def verify_credentials()
    begin
      self.connectServer()
      true
    rescue WIN32OLERuntimeError
      self.raise_win32ole_error($!)
    end
  end
  
  # Return a better, single line, error message for logging
  def raise_win32ole_error(err)
      err = err.to_s.split("\n")
      err.delete_at(-1)
      err.each {|e| e.strip!}
      raise(WIN32OLERuntimeError, err.join(" - "))
  end

	def runProcess(command, async = true, startup = {})
    startup = {:ShowWindow=>1, :Title=>"MIQ - #{Time.now.utc.iso8601}"}.merge(startup)
    objStartup = @objWMI.Get("Win32_ProcessStartup").SpawnInstance_
    startup.each_pair {|k,v| objStartup.send("#{k}=",v)}

    # Obtain the Win32_Process class of object.
    strShell = self.exec_method(@objWMI.Get("Win32_Process"), "Create", :CommandLine => command, :ProcessStartupInformation=> objStartup)

    raise "Failed to create process [#{command}]" if strShell.ProcessID.nil?
    return strShell.ProcessID if async

    if strShell.ReturnValue.zero?
      loop do
        break if @objWMI.ExecQuery("select * from Win32_Process where ProcessID = #{strShell.ProcessID}").count == 0
        if $log
          $log.debug "waiting for remote process [#{strShell.ProcessID}] to end."
        else
          puts "waiting for process [#{strShell.ProcessID}] to end."
        end

        sleep(1)
      end
    end

		return strShell.ReturnValue
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
    wmi_object = @objWMI.InstancesOf(klassName)
    wmi_object.each {|w| yield(w)} if block_given?
    return wmi_object
  end

  def run_query(wmiQuery)
    wmi_object = @objWMI.ExecQuery(wmiQuery)
    wmi_object.each {|s| yield s} if block_given?
    return wmi_object
  end

  def get_instance(wmiQuery)
    wmi_object = nil
    run_query(wmiQuery) {|w| wmi_object = w; break}
    return wmi_object
  end

  def exec_method(wmi_obj, method_name, *input_hash)
    input_hash = input_hash.first || {}
		inParams = wmi_obj.Methods_(method_name.to_s).InParameters.SpawnInstance_
    input_hash.each_pair {|k,v| inParams.send("#{k}=",v)}
		return wmi_obj.ExecMethod_(method_name.to_s, inParams)
  end

  # Call the 'Get' method when you have a __RELPATH or __PATH string to an object
  # Example: \\DEV008-HYPERV\root\CIMV2:Win32_ComputerSystem.Name="DEV008-HYPERV"
  #       or Win32_ComputerSystem.Name="DEV008-HYPERV"
  def get(path)
    @objWMI.Get(path)
  end

  def associators_of(obj, options = {})
    wql = "ASSOCIATORS OF {#{obj.Path_.Path}}"
    wql += " WHERE AssocClass = #{options[:assocClass]}" unless options[:assocClass].nil?
    wql += " WHERE ResultClass = #{options[:resultClass]}" unless options[:resultClass].nil?
    wmi_object = @objWMI.ExecQuery(wql)
    wmi_object.each {|s| yield s} if block_given?
    return wmi_object
  end

  def references_of(obj, options = {})
    wql = "REFERENCES OF {#{obj.Path_.Path}}"
    wql += " WHERE ResultClass = #{options[:resultClass]}" unless options[:resultClass].nil?
    wmi_object = @objWMI.ExecQuery(wql)
    wmi_object.each {|s| yield s} if block_given?
    return wmi_object
  end

  def props_to_hash(wmi_obj)
    h = {}
    wmi_obj.Properties_.each{|p| h[p.name] = p.value}
    h
  end

  def to_h(instance, nh = {}, paths = {}, level = -2)
    level += 2
    i = 0
    #puts "\n\n%0*s[#{level}]======================" % [level,'']
    instance.Properties_.each do |p|
      nh[p.name] = p.value
      #puts "%0*s[#{p.name}] = [#{p.value}]" % [level,'']
    end
    instance.SystemProperties_.each do |p|
      nh[p.name] = p.value
      #puts "%0*s[#{p.name}] = [#{p.value}]" % [level,'']
      paths[p.value]=true if p.name == "__PATH"
    end

#    instance.Associators_.each do |a|
#      klass_name = a.SystemProperties_.each {|p| break(p.value) if p.name == "__CLASS"}
#      next if klass_name == "Msvm_ComputerSystem"
#      next if paths.has_key?(a.Path_.path)
#
#      x = nh["Associator_#{i}"] = {}
#      self.to_h(a, x, paths, level)
#      i += 1
#    end
    return nh
  end
end
