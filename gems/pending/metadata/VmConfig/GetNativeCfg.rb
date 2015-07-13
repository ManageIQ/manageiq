$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'miq-xml'
require 'runcmd'
require 'VmConfig'

class GetNativeCfg
	
	LSHW = "lshw"
	
	def self.new
		lshwXml = MiqUtil.runcmd("#{LSHW} -xml")
		nodeHash = Hash.new { |h, k| h[k] = Array.new }
		doc = MiqXml.load(lshwXml)
		doc.find_match("//node").each { |n| nodeHash[n.attributes["id"].split(':', 2)[0]] << n }

		hardware = ""

		nodeHash["disk"].each do |d|
			diskid = d.find_first('businfo').get_text.to_s
			next if !diskid
			sn = d.find_first('size')
			# If there's no size node, assume it's a removable drive.
			next if !sn
			busType, busAddr = diskid.split('@', 2)
			if busType == "scsi"
				f1, f2 = busAddr.split(':', 2)
				f2 = f2.split('.')[1]
				busAddr = "#{f1}:#{f2}"
			else
				busAddr['.'] = ':'
			end
			diskid = busType + busAddr
			filename = d.find_first('logicalname').get_text.to_s
			hardware += "#{diskid}.present = \"TRUE\"\n"
			hardware += "#{diskid}.filename = \"#{filename}\"\n"
		end
		
		return VmConfig.new(hardware)
	end
	
end

if __FILE__ == $0
	
	cfg = GetNativeCfg.new
	cfg.getDiskFileHash.each { |dtag, df| puts "#{dtag}\t=> #{df}" }
	
end
