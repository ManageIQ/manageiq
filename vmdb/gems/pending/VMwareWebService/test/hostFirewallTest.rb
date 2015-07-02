$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
require 'MiqVimBroker'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump = true

TARGET_HOST = raise "please define"
hMor = nil

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

    miqHost = vim.getVimHost(TARGET_HOST)

	# vim.dumpObj(vim.getMoProp(miqHost.hMor))
	# exit

	puts "Host name: #{miqHost.name}"
    puts

	puts "**** configManager:"
	vim.dumpObj(miqHost.configManager)
	puts "****************************************************************"
	puts
	
	raise "Host has no filrwall system" if !(fws = miqHost.firewallSystem)
	fwi = fws.firewallInfo
	
	puts "**** firewallInfo:"
	vim.dumpObj(fwi)
	puts "****************************************************************"
	puts
	
	puts "**** Refreshing firewall..."
	fws.refreshFirewall
	puts "**** Done."
	puts
	
	defaultPolicy = fws.firewallInfo.defaultPolicy
	
	puts "**** Default Pilicy:"
	vim.dumpObj(defaultPolicy)
	puts "****************************************************************"
	puts
	
	ob0 = defaultPolicy.outgoingBlocked
	defaultPolicy.outgoingBlocked = (defaultPolicy.outgoingBlocked == 'false' ? 'true' : 'false')
	
	puts "**** Updating default policy..."
	fws.updateDefaultPolicy(defaultPolicy)
	puts "**** Done."
	puts
	
	puts "**** Default Pilicy:"
	vim.dumpObj(fws.firewallInfo.defaultPolicy)
	puts "****************************************************************"
	puts
	
	puts "**** Resetting default policy..."
	defaultPolicy.outgoingBlocked = ob0
	fws.updateDefaultPolicy(defaultPolicy)
	puts "**** Done."
	puts
	
	puts "**** Default Pilicy:"
	vim.dumpObj(fws.firewallInfo.defaultPolicy)
	puts "****************************************************************"
	puts
	
	puts "**** SSH Client rules:"
	sshRs = fws.getRulesByFilter('label' => 'SSH Client').first
	if !sshRs
		puts "Rules for SSH Client not found."
		exit
	end
	vim.dumpObj(sshRs)
	puts "****************************************************************"
	puts
	
	if sshRs.enabled == 'false'
		puts "**** SSH Client rules disabled, enabling..."
		fws.enableRuleset(sshRs.key)
		puts "**** Done."
		puts
		
		puts "**** Refreshing firewall..."
		fws.refreshFirewall
		puts "**** Done."
		puts
		
		puts "**** SSH Client rules:"
		sshRs = fws.getRulesByFilter('label' => 'SSH Client').first
		if !sshRs
			puts "Rules for SSH Client not found."
			exit
		end
		vim.dumpObj(sshRs)
		puts "****************************************************************"
		puts
		
		if sshRs.enabled == 'false'
			puts "**** SSH Client rules not enabled."
			exit
		end
		
		puts "**** Disabling SSH Client rules."
		fws.disableRuleset(sshRs.key)
		puts "**** Done."
		puts
		
		puts "**** Refreshing firewall..."
		fws.refreshFirewall
		puts "**** Done."
		puts
		
		puts "**** SSH Client rules:"
		sshRs = fws.getRulesByFilter('label' => 'SSH Client').first
		if !sshRs
			puts "Rules for SSH Client not found."
			exit
		end
		vim.dumpObj(sshRs)
		puts "****************************************************************"
		puts
		
		if sshRs.enabled == 'true'
			puts "**** SSH Client rules not disabled."
			exit
		end
	else
		puts "**** SSH Client rules already enabled."
	end
	
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqHost.release if miqHost
    vim.disconnect
end
