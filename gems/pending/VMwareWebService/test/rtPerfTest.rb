$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'enumerator'
require 'MiqVim'
require 'MiqVimBroker'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	@@prog = File.basename(__FILE__, ".*")
	def format(event)
		"#{Log4r::LNAMES[event.level]} [#{datetime}] -- #{@@prog}: " +
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
	
	private
	
	def datetime
		time = Time.now.utc
		time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d" % time.usec
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$stdout.sync = true
$stderr.sync = true

$miq_wiredump = false

begin
	vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

    miqPh = vim.getVimPerfHistory
    
    vm    = "MIQ-ITUNES"
	# vm    = "rpo-test2"
    host  = raise "please define"
    host2 = raise "please define"
    
    hostMor = vim.hostSystems[host]['MOR']
    raise "Host #{host} not found" if !hostMor
    
    puts "*** Calling: queryProviderSummary for #{host}"
    psum = miqPh.queryProviderSummary(hostMor)
    puts "\tsummarySupported  = #{psum['summarySupported']}"
    puts "\tcurrentSupported  = #{psum['currentSupported']}"
    puts "\trefreshRate       = #{psum['refreshRate']}"
    puts
        
    puts "*** Calling: availMetricsForEntity"
    pmids = miqPh.availMetricsForEntity(hostMor, :intervalId => psum['refreshRate'])
    #puts "*** Available Counters for: #{host}"
    #pmids.each do |pmid|
    #    cinfo = miqPh.id2Counter[pmid.counterId]
    #    puts "\t#{cinfo['groupInfo']['key']}.#{cinfo['nameInfo']['key']}"
    #    puts "\t\tcounterId = #{pmid.counterId}"
    #    puts "\t\tinstance = #{pmid.instance}"
    #end
    puts
    
    vmo = vim.virtualMachinesByFilter("config.name" => vm)
    if vmo.empty?
        puts "VM: #{vm} not found"
        exit
    end
    vmMor = vmo[0]['MOR']
    
    # vim.dumpObj(vmo[0])
    puts "*** Calling: queryProviderSummary for #{vm}"
    psum = miqPh.queryProviderSummary(vmMor)
    # vim.dumpObj(psum)
    puts
    
    puts "Calling: availMetricsForEntity"
    pmids = miqPh.availMetricsForEntity(vmMor, :intervalId => psum['refreshRate'])
    puts "*** Available Counters for: #{vm}"
    pmids.each do |pmid|
        cinfo = miqPh.id2Counter[pmid.counterId]
        puts "\t#{cinfo['groupInfo']['key']}.#{cinfo['nameInfo']['key']}"
        puts "\t\tcounterId = #{pmid.counterId}"
        puts "\t\tinstance = #{pmid.instance}"
    end
    puts
    
    cpurdyi = miqPh.getCounterInfo('cpu', 'ready', 'summation', 'delta')
	# cpurdyi = miqPh.getCounterInfo('cpu', 'used', 'summation', 'delta')
    puts "cpurdyi = #{cpurdyi['key']}"
    puts
    puts "miqPh: #{miqPh.class}, ID = 0x#{miqPh.object_id.to_s(16)}"
    
    # ma = miqPh.queryPerf(vmMor, :counterId => cpurdyi['key'], :instance => "*", :intervalId => psum['refreshRate'], :maxSample => 1)
    # ma.each_slice(2) { |t, v| puts ":\tValue: #{v}\t\tTIme: #{t.to_s}" }
    # puts

    vma = vim.virtualMachinesByFilter("summary.runtime.hostName" => host2)
    
    metricId = [ { :counterId => cpurdyi['key'], :instance => "0" } ]
    ea = Array.new
    
    puts "VMs on: #{host2}"
    vma.each do |vmo|
        puts "\t#{vmo['config']['name']}"
        ea << { :entity => vmo['MOR'],  :intervalId => psum['refreshRate'], :metricId => metricId }
    end
    puts
	# ea << { :entity => vmMor,  :intervalId => psum['refreshRate'], :metricId => metricId }
    
    pcm = miqPh.queryPerfMulti(ea)
	vim.dumpObj(pcm)
	exit

	tsHash = Hash.new { |h, k| h[k] = Array.new }
	pcm.each do |pem|
		sInfo = pem['sampleInfo']
		va = pem['value']['value']
		sInfo.each_index do |si|
			ts = sInfo[si]['timestamp'].to_s
			tsHash[ts] << va[si]
		end
	end
	puts
	
	puts "*** Average VM CPU ready time by time-slice:"
	tsHash.keys.sort.each do |ts|
		va = tsHash[ts]
		sum = 0
		va.each { |v| sum += v.to_i }
		avg = sum/va.length
		print ":\t#{ts}: [NV = #{va.length}, AVG = #{avg}]"
		va.each { |v| print ", #{v}" }
		puts
	end
	
	# puts "**** queryPerfMulti start"
    # vim.dumpObj(pcm)
    # puts "**** queryPerfMulti end"
    
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    miqPh.release if miqPh
    vim.disconnect if vim
end
