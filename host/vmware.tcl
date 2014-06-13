
namespace eval vmware {

    proc split= { what } {
        set index [string first = $what]
        if { $index == -1 } { error "No EQUAL(=) sign in $what" }
        set left  [string range $what 0 [expr { $index - 1 }]]
        set right [string range $what [expr { $index + 1 }] end]
        set left  [string trim $left]
        set right [string trim $right]
        return [list $left $right]
    }

    proc getValue= { what } { lindex [split= $what] 1 }

	proc getConnectedUsers { vm } {
		set users [exec vmware-cmd $vm getconnectedusers]
	}
    
    proc getState { vm }           { getValue= [exec vmware-cmd $vm getstate] }
	proc getConfigFile { vm }      { getValue= [exec vmware-cmd $vm getconfigfile] }
	proc getConfig { vm var }      { getValue= [exec vmware-cmd $vm getconfig $var] }
	proc hasSnapshot { vm }        { getValue= [exec vmware-cmd $vm hassnapshot] }
	
	proc getToolsLastActive { vm } {
	    if { [getState $vm] == "off" } { return "" }
		getValue= [exec vmware-cmd $vm gettoolslastactive]
	}
	
	proc getHeartbeat { vm } {
	    if { [getState $vm] == "off" } { return "" }
		getValue= [exec vmware-cmd $vm getheartbeat]
	}
	
	proc getProductInfo { vm } {
		set info [exec vmware-cmd $vm getproductinfo]
	}
	

    proc start { vm { type soft } } {
        if { [getState $vm] == "on" } { return "already started" }
		set result [exec vmware-cmd $vm start $type]
		set result [lindex [split= $result] 1]
		if { $result == 1 } { return "ok" }
		return $result
    }

    proc errorMessage { emsg } {
		if { [string first "ServerFaultCode(1606)" $emsg] != -1 } {
		    set emsg "1606: VMware Tools are not running"
		}
		
		return $emsg
    }
    
    proc stop { vm { type soft } } {
        if { [catch {
		  set result [exec vmware-cmd $vm stop $type]
		} emsg] } {
          error [errorMessage $emsg]
		}
		
		set result [lindex [split= $result] 1]
		if { $result == 1 } { return "ok" }
		return $result
    }
    
    proc suspend { vm { type soft } } {
		set result [exec vmware-cmd $vm suspend $type]
    }
    
    proc reset { vm { type soft } } {
		set result [exec vmware-cmd $vm reset $type]
    }

    proc getVersion { } {
		set version [exec vmware -v]
    }
    
    
	proc getVMs { } {
		set vms {}

		set result [exec vmware-cmd -l]

		foreach vm [split $result \n] {
			lappend vms $vm
		}

		return $vms
	}
}

puts "ESX Version: [vmware::getVersion]"
foreach vm [vmware::getVMs] {
    catch { unset VM }
    set VM(name)        $vm
    set VM(state)       [vmware::getState $vm]
    set VM(users)       [vmware::getConnectedUsers $vm]
    set VM(heartbeat)   [vmware::getHeartbeat $vm]
    set VM(configfile)  [vmware::getConfigFile $vm]
    set VM(hasSnapshot) [vmware::hasSnapshot $vm]
#    set VM(productInfo) [vmware::getProductInfo $vm]
    set VM(tools)       [vmware::getToolsLastActive $vm]
    foreach var [list memsize] { 
        set VM([string toupper $var])   [vmware::getConfig $vm $var]
    }
    
    parray VM
    puts "========================================"  
}

foreach vm [vmware::getVMs] {
    puts "Working with VM: $vm"
    
    puts "\tState=[vmware::getState $vm]"
    
    puts "\tSTARTing..."
    set result [vmware::start $vm]
    puts "\tSTARTed....$result"
    
    puts "\tState=[vmware::getState $vm]"
    
#    puts "\tSUSPENDing..."
#    set result [vmware::suspend $vm]
#    puts "\tSUSPENDed....$result"

    puts "\tSTOPPing..."
    set result [vmware::stop $vm hard]
    puts "\tSTOPPed....$result"
}


