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

# $DEBUG = true
$miq_wiredump = true

HOST = nil

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	host = nil
	raise "Host: #{HOST} not found" if HOST && !(host = vim.hostSystems[HOST])
	host = host['MOR'] if host
	
	rv = vim.queryLogDescriptions(host)
	
	rv.each do |d|
		puts d['fileName']
		puts "\tDescription: " + d['info']['summary']
		puts "\tCreator: " + d['creator']
		puts "\tFormat: " + d['format']
		puts "\tKey: " + d['key']
		puts
		
		bdl = vim.browseDiagnosticLog(d['key'], nil, nil, host)
		vim.dumpObj(bdl)
		puts "\tLine start: " + bdl['lineStart'].to_s
		puts "\tLine end: " + bdl['lineEnd'].to_s
		puts "\tContents:"
		bdl['lineText'].each { |l| puts "\t\t" + l }
		puts
	end

    exit

  # Verify calling browseDiagnosticLogEx with various start, lines combinations
  puts
  [
    [nil, 999],
    [nil, 1000],
    [nil, 1001],
    [nil, 2000],
    [100, 200],
    [100, 2000],
    [nil, 100000],
    [nil, nil],
  ].each do |start, lines|
    puts "browseDiagnosticLogEx: start [#{start}], lines [#{lines}]"
    bdl = vim.browseDiagnosticLogEx('host', start, lines, host)
    puts "\tLine start: " + bdl['lineStart'].to_s
    puts "\tLine end: " + bdl['lineEnd'].to_s
    puts "\tContents: " + bdl['lineText'].length.to_s
    puts
  end
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    vim.disconnect if vim
end
