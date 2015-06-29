$:.push("#{File.dirname(__FILE__)}/../../util")

require 'binary_struct'
require 'miq-hash_struct'
require 'miq-xml'

module MiqLinux
  
  class Users
		attr_reader :userHash, :groups
	
		def initialize(fs)
			@userHash = Hash.new
			@usersByGid = Hash.new { |h, k| h[k] = Array.new }
			@groups = []
          
			wtmp = FileWTMP.new(fs)
			
			fname = "/etc/passwd"
			if fs.fileExists?(fname)
				pfes = nil
				fs.fileOpen(fname) { |fo| pfes = fo.read }
				unless pfes.nil?
					pfes.each_line do |pfe|
						next if pfe =~ /^#/
						fields = pfe.chop.split(':')
						u = MiqHashStruct.new
						u.name       = fields[0]
						u.uid        = fields[2]
						u.gid        = fields[3]
						u.gecos      = fields[4]
						u.dir        = fields[5]
						u.shell      = fields[6] || "NONE"
						u.last_logon = wtmp.last_logon(u.name) unless wtmp.nil?
						u.groups     = []
						@userHash[u.name] = u
						@usersByGid[u.gid] << u
					end
				end
			end
          
			fname = "/etc/group"
			if fs.fileExists?(fname)
				pfes = nil
				fs.fileOpen(fname) { |fo| pfes = fo.read }
				unless pfes.nil?
					pfes.each_line do |pfe|
						next if pfe =~ /^#/
						fields = pfe.chop.split(':')
						g = MiqHashStruct.new
						g.name  = fields[0]
						g.gid   = fields[2]
						g.ulist = fields[3].split(',') if fields[3]
						g.ulist = [] if !g.ulist
						@usersByGid[g.gid].each { |u| g.ulist << u.name }
						g.ulist.uniq!
						g.ulist.each { |un| @userHash[un].groups << g.name if @userHash[un] }
						@groups << g
					end
				end
			end
			@userHash.each_value { |u| u.groups.uniq! }
		end
		
		def to_s
			str = String.new
          
			@userHash.each_value do |u|
				str += "Login: "     + u.name
				str += "\n\tUid: "   + u.uid.to_s
				str += "\n\tGid: "   + u.gid.to_s
				str += "\n\tHome: "  + u.dir
				str += "\n\tShell: " + u.shell
				str += "\n\tGECOS: " + u.gecos
				str += "\n\tGroups: "
				u.groups.each { |gn| str += "\n\t\t#{gn}"}
				str += "\n"
			end
          
			@groups.each do |g|
				str += "Group Name: " + g.name
				str += "\n\tGid: "    + g.gid
				str += "\n\tUsers:"
				g.ulist.each { |un| str += "\n\t\t#{un}"}
				str += "\n"
			end
			return(str)
		end
    
		def to_xml(doc=nil)
			doc = MiqXml.createDoc(nil) if !doc
			usersToXml(doc)
			groupsToXml(doc)
			doc
    end

		def usersToXml(doc=nil)
			doc = MiqXml.createDoc(nil) if !doc
          
			users = doc.add_element('users')
			@userHash.each_value do |u|
				user = users.add_element('user', {'name' => u.name, 'userid' => u.uid, 'homedir' => u.dir})
				user.add_attribute('comment', u.gecos) unless u.gecos.blank?
				user.add_attribute('last_logon', u.last_logon) unless u.last_logon.nil? || u.last_logon.blank?
              
				u.groups.each do |gn|
					user.add_element('member_of_group', {'name' => gn})
				end
			end
			doc
		end
    
		def groupsToXml(doc=nil)
			doc = MiqXml.createDoc(nil) if !doc     
           
			groups = doc.add_element('groups')
			@groups.each do |g|
				group = groups.add_element('group', {'name' => g.name, 'groupid' => g.gid})
              
				g.ulist.each do |un|
					group.add_element('member_users', {'name' => un}) 
				end
			end
			doc
		end

  end # class Users
  
  class FileWTMP
    # From http://www.hcidata.info/wtmp.htm
		# 
    # The wtmp log file is usually found in /var/log/wtmp and contains the following information:
    # 
    #         * Activity code (e.g. login, logout, boot)
    #         * PID
    #         * Date and time of last login
    #         * Terminal line name
    #         * Host user came from
    # 
    #     The following one line PERL program will format and print /var/log/wtmp but it may need modification to work on your site.
    # 
    #     perl -we '@type=("Empty","Run Lvl","Boot","New Time","Old Time","Init","Login","Normal","Term","Account");$recs = ""; while (<>) {$recs .= $_};foreach (split(/(.{384})/s,$recs)) {next if length($_) == 0;my ($type,$pid,$line,$inittab,$user,$host,$t1,$t2,$t3,$t4,$t5) = $_ =~/(.{4})(.{4})(.{32})(.{4})(.{32})(.{256})(.{4})(.{4})(.{4})(.{4})(.{4})/s;if (defined $line && $line =~ /\w/) {$line =~ s/\x00+//g;$host =~ s/\x00+//g;$user =~ s/\x00+//g;printf("%s %-8s %-12s %10s %-45s \n",scalar(gmtime(unpack("I4",$t3))),$type[unpack("I4",$type)],$user,$line,$host)}}print"\n"' < /var/log/wtmp
    # 
    #     The items that may need modification in order to format and print your lastlog file are:
    # 
    #         * 384 - this should be changed to the length of each record on /var/log/wtmp.
    #         * 32 - this should be changed to the value of UT_LINESIZE (probably 32) in /usr/include/bits/utmp.h
    #         * 32 - this should be changed to the value of UT_NAMESIZE](probably 32) in /usr/include/bits/utmp.h
    #         * 256 - this should be changed to the value of UT_HOSTSIZE (probably 256) in /usr/include/bits/utmp.h
    #         * /var/log/wtmp - this should be the name of the lastlog file on your system - probably /var/log/wtmp
    #     

    WTMP_RECORD = BinaryStruct.new([
        'V',        'type',          # type of login
        'V',        'pid',           # PID of login process
        'a32',      'line',          # device name of tty - "/dev/"
        'V',        'inittab',       # init id or abbrev. ttyname
        'a32',      'user',          # user name
        'a256',     'host',          # hostname for remote login
        'v',        'e_termination', # process termination status
        'v',        'e_exit',        # process exit status
        'V',        'session',       # Session ID, used for windowing
        'V',        'seconds',       # Time, in seconds
        'V',        'useconds',      #     microseconds
        'V4',       'addr_v6',       # * Internet address of remote host; IPv4 address uses just ut_addr_v6[0] */
        'a20',      'extra'
    ])
    WTMP_RECORD_LEN = WTMP_RECORD.size

    # WTMP Account Types
    WTMP_TYPE_UT_UNKNOWN    = 0
    WTMP_TYPE_RUN_LVL       = 1
    WTMP_TYPE_BOOT_TIME     = 2
    WTMP_TYPE_NEW_TIME      = 3
    WTMP_TYPE_OLD_TIME      = 4
    WTMP_TYPE_INIT_PROCESS  = 5
    WTMP_TYPE_LOGIN_PROCESS = 6
    WTMP_TYPE_USER_PROCESS  = 7
    WTMP_TYPE_DEAD_PROCESS  = 8
    WTMP_TYPE_ACCOUNTING    = 9

    WTMP_TYPES = {
      WTMP_TYPE_UT_UNKNOWN    => "Unknown",
      WTMP_TYPE_RUN_LVL       => "Run Level",
      WTMP_TYPE_BOOT_TIME     => "Boot Time",
      WTMP_TYPE_NEW_TIME      => "New Time",
      WTMP_TYPE_OLD_TIME      => "Old Time",
      WTMP_TYPE_INIT_PROCESS  => "Init Process",
      WTMP_TYPE_LOGIN_PROCESS => "Login Process",
      WTMP_TYPE_USER_PROCESS  => "User Process",
      WTMP_TYPE_DEAD_PROCESS  => "Dead Process",
      WTMP_TYPE_ACCOUNTING    => "Accounting"
    }

    def initialize(fs, path="/var/log/wtmp")
      @contents = nil
      @records  = nil
      begin
 			  fs.fileOpen(path) { |fo| @contents = fo.read }
      rescue
      end
    end

	  def last_logon(username)
	    return nil if @contents.nil?
	    last = nil
	    
	    begin
        records.each { |rec| 
    			next unless rec["user"] == username
    			next unless rec["type"] == WTMP_TYPE_USER_PROCESS
      	  current = rec["seconds"]
      	  last = current if last.nil? || current > last
        }

        last = Time.at(last).getutc unless last.nil?
      rescue => err
        $log.error("Error processing WTMP file because <#{err.message}>") if $log
      end
      last
    end

    def dump(rec)
      puts "WTMP Record:"
  #      puts "WTMP Record: #{rec.inspect}"
      puts "\ttype: #{WTMP_TYPES[rec["type"]]}"
      puts "\tuser: #{rec["user"]}"
      puts "\thost: #{rec["host"]}"
      puts "\tline: #{rec["line"]}"
      puts "\tpid:  #{rec["pid"]}"
      puts "\ttime: #{Time.at(rec["seconds"])}"
    end

    def records
      return @records unless @records.nil?
  	  recs  = Array.new
	    recnum = 0
	    nrecs  = @contents.length / WTMP_RECORD_LEN
      while recnum < nrecs do
        offset  = recnum*WTMP_RECORD_LEN
        recnum += 1
        buf     = @contents[offset,WTMP_RECORD_LEN]
        break unless buf.length == WTMP_RECORD_LEN
  			rec = WTMP_RECORD.decode(buf)
  			['host', 'user', 'line'].each { |k| rec[k].strip! if rec[k] }
  			recs << rec
      end
      @records = recs      
      @records
    end

  end # class FileWTMP

end # module MiqLinux

if __FILE__ == $0
	$:.push("#{File.dirname(__FILE__)}/../../MiqVm")
    
	require 'rubygems'
	require 'log4r'
	require 'MiqVm'
	
	vmDir = File.join(ENV.fetch("HOME", '.'), 'VMs')
	puts "vmDir = #{vmDir}"
    
	class ConsoleFormatter < Log4r::Formatter
		def format(event)
			(event.data.kind_of?(String) ? event.data : event.data.inspect)
		end
	end

	toplog = Log4r::Logger.new 'toplog'
	Log4r::StderrOutputter.new('err_console', :level=>Log4r::ERROR, :formatter=>ConsoleFormatter)
	toplog.add 'err_console'
	$log = toplog if $log.nil?
    
	#
	# *** Test start
	#
    
	vmCfg = File.join(vmDir, "Red Hat Linux.vmwarevm/Red Hat Linux.vmx")
	# vmCfg = File.join(vmDir, "MIQ Server Appliance - Ubuntu MD - small/MIQ Server Appliance - Ubuntu.vmx")
	# vmCfg = File.join(vmDir, "winxpDev.vmwarevm/winxpDev.vmx")
	vmCfg = "/Volumes/OB VMs/vms/Ubuntu Subversion/Ubuntu.vmx"
	puts "VM config file: #{vmCfg}"
    
	vm = MiqVm.new(vmCfg)
	raise "No OSs detected" if vm.vmRootTrees.length == 0
	rt = vm.vmRootTrees[0]
	u = MiqLinux::Users.new(rt)
	puts "**** USERS:"
	u.usersToXml.write($stdout, 4)
	puts
	puts "**** GROUPS:"
	u.groupsToXml.write($stdout, 4)
	puts
end
