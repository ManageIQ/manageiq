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
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# MiqVimClientBase.wiredump_file = "perf.txt"

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
    
    endTime = vim.currentServerTime
    puts "Current server time: #{endTime}"
    puts

    miqPh = vim.getVimPerfHistory
	# vim.dumpObj(miqPh.intervals)
    
    puts "Available historical archive sampling intervals:"
    miqPh.intervals.each { |i| puts "\t#{i['name']}: Sampling Period = #{i['samplingPeriod']}(secs), length = #{i['length']}" }
    puts
    
    puts "Counter Groups:"
    miqPh.groupInfo.each { |gk, gi| puts "\t#{gk}: label = #{gi['label']}, summary = #{gi['summary']}" }
    puts
    
    puts "Counters by group:"
    miqPh.cInfoMap.each do |gn, nh|
        puts "\tGROUP: #{gn}"
        nh.each do |n, ca|
            puts "\t\tNAME: #{gn}.#{n}"
            # ca.each_index do |ci|
            #     co = ca[ci]
            #     puts "\t\t\tCOUNTER[#{ci}]:"
            #     puts "\t\t\t\tSummary: #{co['nameInfo']['summary']}"
            #     puts "\t\t\t\tLabel: #{co['nameInfo']['label']}"
            #     puts "\t\t\t\tRollup type: #{co['rollupType']}"
            #     puts "\t\t\t\tStats type: #{co['statsType']}"
            #     puts "\t\t\t\tLevel: #{co['level']}"
            #     puts "\t\t\t\tKey: #{co['key']}"
            #     puts
            # end
        end
    end
    
    # iid = '3600'
    iid = '7200'
    
    startTime = endTime - 1
    
    puts "Start Time: #{startTime}"
    puts "End Time:   #{endTime}"
    puts
    
	ha = vim.hostSystemsByMor.values
	h1 = ha[0]
	h2 = ha[1]
	
	host  = h1['config']['name'] if h1
	host2 = h2['config']['name'] if h2
	
    hostMor = h1['MOR']
    raise "Host #{host} not found" if !hostMor
    
    puts "Calling: queryProviderSummary for #{host}"
    psum = miqPh.queryProviderSummary(hostMor)
    # vim.dumpObj(psum)
    # puts
    
    puts "Calling: availMetricsForEntity"
    # pmids = miqPh.availMetricsForEntity(hostMor, :intervalId => iid, :beginTime => startTime, :endTime => endTime)
    pmids = miqPh.availMetricsForEntity(hostMor, :intervalId => psum['refreshRate'])
    # puts "Available Counters for: #{host}"
    # pmids.each do |pmid|
    #     cinfo = miqPh.id2Counter[pmid.counterId]
    #     puts "\t#{cinfo['groupInfo']['key']}.#{cinfo['nameInfo']['key']}"
    #     puts "\t\tcounterId = #{pmid.counterId}"
    #     puts "\t\tinstance = #{pmid.instance}"
    # end
    # puts
    
    ci  = miqPh.getCounterInfo('cpu', 'usage', 'average', 'rate')
    ci2 = miqPh.getCounterInfo('mem', 'usage', 'average', 'absolute')
    
    puts "#{miqPh.intervalMap[iid]['name']} average CPU usage for #{host} (sampled every #{iid} seconds):"
    units = ci['unitInfo']['label']

    ma = miqPh.queryPerf(hostMor, :counterId => ci['key'], :intervalId => iid, :startTime => startTime, :endTime => endTime)
    ma.each_slice(2) { |t, v| puts ":\tValue: #{v*0.01} (#{units})\t\tTIme: #{t}" }
    puts
    
    puts "**** queryPerfComposite start"
    pc = miqPh.queryPerfComposite(hostMor, :counterId => ci['key'], :intervalId => iid, :startTime => startTime, :endTime => endTime)
    puts "Parent MOR: #{pc['entity']['entity']}, Type: #{pc['entity']['entity'].vimType}"
    puts "Child MORs:"
    pc['childEntity'].each { |e| puts "\tMOR: #{e['entity']}, Type: #{e['entity'].vimType}"}
    # puts
    # vim.dumpObj(pc)
    puts "**** queryPerfComposite end"
    puts
    
    host2Mor = h2['MOR']
    raise "Host #{host2} not found" if !host2Mor
    
    metricId = [ { :counterId => ci['key'], :instance => "" }, { :counterId => ci2['key'], :instance => "" } ]
    e1h = { :entity => hostMor,  :intervalId => iid, :metricId => metricId, :startTime => startTime, :endTime => endTime }
    e2h = { :entity => host2Mor, :intervalId => iid, :metricId => metricId, :startTime => startTime, :endTime => endTime }

	# $miq_wiredump = true
    
    puts "**** queryPerfMulti start"
    pcm = miqPh.queryPerfMulti([e1h, e2h])
    # vim.dumpObj(pcm)
    puts "**** queryPerfMulti end"
    
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    miqPh.release if miqPh
    vim.disconnect if vim
end
