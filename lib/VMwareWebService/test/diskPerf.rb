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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$stdout.sync = true
$stderr.sync = true

$miq_wiredump = false

host2 = raise "please define"
vm = raise "please define"

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

    miqPh = vim.getVimPerfHistory
	puts "*** Avail intervals:"
	vim.dumpObj(miqPh.intervals)
	puts
    
    vmo = vim.virtualMachinesByFilter("config.name" => vm)
    if vmo.empty?
        puts "VM: #{vm} not found"
        exit
    end
    vmMor = vmo[0]['MOR']
    
    # vim.dumpObj(vim.getMoProp(vmMor))
    puts "*** Calling: queryProviderSummary for #{vm}"
    psum = miqPh.queryProviderSummary(vmMor)
    vim.dumpObj(psum)
    puts
    
    puts "Calling: availMetricsForEntity"
    pmids = miqPh.availMetricsForEntity(vmMor, :intervalId => psum['refreshRate'])

    puts "*** Available Counters for: #{vm}"
    pmids.each do |pmid|
        cinfo = miqPh.id2Counter[pmid.counterId]
        puts "\t#{cinfo['groupInfo']['key']}.#{cinfo['nameInfo']['key']}"
        puts "\t\tcounterId = #{pmid.counterId}"
        puts "\t\tinstance = >#{pmid.instance}<"
    end
    puts
    
    numberRead	= miqPh.getCounterInfo('disk', 'numberRead',	'summation',	'delta')
	numberWrite	= miqPh.getCounterInfo('disk', 'numberWrite',	'summation',	'delta')
	read		= miqPh.getCounterInfo('disk', 'read',			'average',		'rate')
	write		= miqPh.getCounterInfo('disk', 'write',			'average',		'rate')

	metricId =	[
		{ :counterId => numberRead['key'],	:instance => "*" },
		# { :counterId => numberWrite['key'],	:instance => "*" },
		# { :counterId => read['key'],		:instance => "*" },
		# { :counterId => write['key'],		:instance => "*" }
	]
	ea = [ { :entity => vmMor,  :intervalId => psum['refreshRate'], :metricId => metricId } ]
	
	pcm = miqPh.queryPerfMulti(ea)
	vim.dumpObj(pcm)

	exit

    vma = vim.virtualMachinesByFilter("summary.runtime.hostName" => host2)
    
    metricId = [ { :counterId => numberRead['key'], :instance => "*" } ]
    ea = Array.new
    
    puts "VMs on: #{host2}"
    vma.each do |vmo|
        puts "\t#{vmo['config']['name']}"
        ea << { :entity => vmo['MOR'],  :intervalId => psum['refreshRate'], :metricId => metricId }
    end
    puts
    
    pcm = miqPh.queryPerfMulti(ea)
	vim.dumpObj(pcm)

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
