$:.push("#{File.dirname(__FILE__)}/../../VMwareWebService")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'miq-xml'
require 'VimInventory'
require 'miq-password'

class VMWareWebSvcOps
    
    def initialize(ost)
    end
    
	def GetEmsInventory(ost)
	    emsName = ost.args[0] || "vmwarews"
	    emsh = getEmsh(ost, emsName)
	    emsh['name'] = emsName
	    ost.emsEnt = emsh
	
	    vi = VimInventory.new(emsh["host"], emsh["user"], MiqPassword.decrypt(emsh["password"]))
	    
	    doc = MiqXml.createDoc("<emsInventory/>",
	            {"emshost" => emsh["host"], "emsname" => emsName, "emsuser" => emsh["user"]})

        MIQRexml.addObjToXML(doc.root, "Datastores", vi.inventoryHash["Datastore"])

        hsHash = Hash.new
        vi.inventoryHash["HostSystem"].each do |n, mo|
            prop = vi.getMoProp(mo, "summary")
            smry = prop[0][0]["summary"]
            hsHash[n] = smry
        end

        MIQRexml.addObjToXML(doc.root, "HostSystems", hsHash)
        vi.disconnect
        
        ost.xml = true
        ost.encode = true
        ost.value = doc.to_s
	end
	
	def MonitorEmsEvents(ost)
	    emsName = ost.args[0] || "vmwarews"
	    emsh = getEmsh(ost, emsName)
	    emsh['name'] = emsName
	    ost.emsEnt = emsh
	    
	    require 'VmwareEventAgent'
	    
	    ea = VmwareEventAgent.new(emsh["host"], emsh["user"], MiqPassword.decrypt(emsh["password"]), ost)
	    ea.doEvents
	    # Does not return
	end
	
private

    def getEmsh(ost, emsName)
        raise "Unknown external management system: #{emsName}" if !ost.config.ems || !(emsh = ost.config.ems[emsName])
        emsh
    end
    
    def getLoginInfo(emsh)
        return emsh["host"], emsh["user"], MiqPassword.decrypt(emsh["password"])
    end
	
end
