$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../util/win32")
require 'miq-extensions'
require 'miq-xml'
require 'miq-hash_struct'
require 'miq-wmi'

class MiqHypervService
  WMIDTD20 = 1

  def initialize(server=nil, username=nil, password=nil)
    @server, @username, @password  = server, username, password
    @connected = false
  end

  def connect()
    @wmi = WMIHelper.connectServer(@server, @username, @password, 'root\\virtualization')
  end

  def disconnect()
    @wmi.release unless @wmi.nil?
    @wmi = nil
    @connected = false
  end

	def requestStateChange(wmi_obj, state, wait=true)
    return wmi_execute_method(wmi_obj, "RequestStateChange", "RequestedState" => state)
	end

  def renameSnapshot(vmh, sn, name, desc)
    sn.ElementName = name
    sn.Notes = desc
    return self.wmi_update_system('ModifyVirtualSystem', {'ComputerSystem'=>vmh.Path_.Path, 'SystemSettingData'=>sn.GetText_(WMIDTD20)})
	end # def renameSnapshot

  def applyVirtualSystemSnapshotEx(vmh, sn)
    return self.wmi_update_system('ApplyVirtualSystemSnapshotEx', {'ComputerSystem'=>vmh.Path_.Path, 'SnapshotSettingData'=>sn.Path_.Path})
  end

  def shutdownGuest(shutdown_obj, msg='', force=true)
    return wmi_execute_method(shutdown_obj, "InitiateShutdown", {"Force" => force, 'Reason' => msg})
  end

  def wmi_update_system(method_name, method_hash, wait=true)
    @vsms = self.management_service if @vsms.nil?
    return wmi_execute_method(@vsms, method_name, method_hash)
  end

  def management_service
    @wmi.collect_first("select * from Msvm_VirtualSystemManagementService")
  end

  # Execute WMI method and return the following Array:
  # [0] = Return Code
  # [1] = Object Returned from exec_method
  # [2] = Job object (when available)
  def wmi_execute_method(target_obj, method_name, method_hash, wait=true)
    hnd = @wmi.exec_method(target_obj, method_name, method_hash)
    rc = [hnd.ReturnValue, hnd]
    return wmi_wait_for_job(rc) if wait == true and hnd.ReturnValue == 4096
    return rc
  end

  def wmi_wait_for_job(exec_rc)
    loop do
      job = @wmi.get(exec_rc[1].Job)
      if job.JobState >= 7
        # Return job rc and latest job object
        exec_rc[0], exec_rc[2] = job.ErrorCode, job
        return(exec_rc)
      end
      sleep(0.5)
    end
  end

  def self.wmi_format_error(rc)
    msg = @@format_error_codes[rc]
    return "Unknown return code (#{rc})" if msg.nil?
    return "#{msg} (#{rc})"
  end

  def wmi_format_error(rc)
    return self.class.wmi_format_error(rc)
  end

  def self.set_format_error_list
    @@format_error_codes = ['Completed with No Error']
    @@format_error_codes[4096] = 'Method Parameters Checked - Job Started'
    @@format_error_codes.insert(32768, 'Failed', #32768
    'Access Denied',            #32769
    'Not Supported',            #32770
    'Status is unknown',        #32771
    'Timeout',                  #32772
    'Invalid parameter',        #32773
    'System is in used',        #32774
    'Invalid state for this operation', #32775
    'Incorrect data type',      #32776
    'System is not available',  #32777
    'Out of memory',            #32778
    'File not found',           #32779
    'The system is not ready',  #32780
    'The machine is locked and cannot be shut down without the force option', #32781
    'A system shutdown is in progress') #32782
  end
  # Call Initialize error list when the class is first loaded
  self.set_format_error_list

  def dumpObj(obj, prefix=nil, prnt_obj=STDOUT, prnt_meth=:puts)
    self.class.dumpObj(obj, prefix, prnt_obj, prnt_meth)
  end

  def self.dumpObj(obj, prefix=nil, prnt_obj=STDOUT, prnt_meth=:puts)
    meth = "dump#{obj.class.name}".to_sym
    if self.respond_to?(meth)
      prnt_obj.send(prnt_meth, "PATH:#{prefix} (#{obj.class}) = EMPTY\n") if obj.respond_to?(:blank?) && obj.blank?
      self.send(meth, obj, prefix, prnt_obj, prnt_meth)
    else
      prnt_obj.send(prnt_meth, "PATH:#{prefix} (#{obj.class}) = #{obj.inspect}\n")
    end
  end

  def self.dumpWIN32OLE(obj, prefix, prnt_obj, prnt_meth)
    prnt_obj.send(prnt_meth, "PATH:#{prefix} (WIN32OLE)\n#{obj.GetObjectText_.strip} #{obj.Path_.Path}\n\n")
  end

  def self.dumpHash(hd, prefix, prnt_obj, prnt_meth)
    hd.each {|k,v| self.dumpObj(v, "#{prefix}[#{Symbol === k ? ":#{k}" : k}]", prnt_obj, prnt_meth)}
  end

  def self.dumpVimHash(hd, prefix, prnt_obj, prnt_meth)
    self.dumpHash(hd, prefix, prnt_obj, prnt_meth)
  end

  def self.dumpArray(ad, prefix, prnt_obj, prnt_meth)
    ad.inject(0) {|i, d| self.dumpObj(d, "#{prefix}[#{i}]", prnt_obj, prnt_meth);  i+=1}
  end

  def self.dumpVimArray(ad, prefix, prnt_obj, prnt_meth)
    self.dumpArray(ad, prefix, prnt_obj, prnt_meth)
  end
end
