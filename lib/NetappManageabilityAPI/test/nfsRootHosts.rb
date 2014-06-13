$:.push("#{File.dirname(__FILE__)}/..")

require "../util/MiqDumpObj"
require "NmaClient"

NAS_SERVER		= ""
NAS_USERNAME	= ""
NAS_PASSWORD	= ""

VOLUME_NAME		= "rpotest"
ROOT_HOSTS		= [] #ip addresses or host names

class Dump
	include MiqDumpObj
end

begin
	
	dump = Dump.new
	
	puts "Connecting to NAS server: #{NAS_SERVER}..."
	nma = NmaClient.new {
		server		NAS_SERVER
		auth_style	NmaClient::NA_STYLE_LOGIN_PASSWORD
		username	NAS_USERNAME
		password	NAS_PASSWORD
	}
	puts "done."
	puts
	
	rv = nma.nfs_exportfs_list_rules(:pathname, "/vol/#{VOLUME_NAME}")
	raise "No export rules found for path /vol/#{VOLUME_NAME}" unless rv.kind_of?(NmaHash)
	# dump.dumpObj(rv)
	
	rules = rv.rules
	rules.exports_rule_info.root = NmaHash.new if rules.exports_rule_info.root.nil?
	if rules.exports_rule_info.root.exports_hostname_info.nil?
		rules.exports_rule_info.root.exports_hostname_info = NmaArray.new
	else
		rules.exports_rule_info.root.exports_hostname_info = rules.exports_rule_info.root.exports_hostname_info.to_ary
	end
	
	rha = rules.exports_rule_info.root.exports_hostname_info
	
	changed = false
	ROOT_HOSTS.each do |nrhn|
		skip = false
		rha.each do |crhh|
			if crhh.name == nrhn
				skip = true
				break
			end
		end
		next if skip
		
		rha << NmaHash.new { name nrhn }
		changed = true
	end
	
	# dump.dumpObj(rules)
	
	if changed
		puts "Updating rules"
		nma.nfs_exportfs_modify_rule {
			persistent	true
			rule		rules
		}
	else
		puts "No change to rules, not updating"
	end
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
