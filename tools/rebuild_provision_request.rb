#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'optimist'
require 'rest-client'
#
# Helper Script to show the json / hash output of an
# existing Automate request
#
#
# Run without options to see the usage.
#
#

PROGRAM_STRING = "ruby #{$PROGRAM_NAME}".freeze

if ARGV.empty?
  print "\n#{PROGRAM_STRING} --help\n\n"
  exit
end

ARGV.shift if ARGV[0] == '--'

opts = Optimist.options do
  banner <<-EOS

Reconstruct provision request parameters based on an existing request

Common Examples\n\t
Output the hash parameters of a request

  #{PROGRAM_STRING} --request-id=3

Show the hash parameters and the console command needed to rerun a request

  #{PROGRAM_STRING} --request-id=3  --console

Show the hash parameters and rerun the request

  #{PROGRAM_STRING} --request-id=3  --run-it

Show a list of 5 recent requests

  #{PROGRAM_STRING} --last-requests

Help! #{PROGRAM_STRING} --help

Usage: #{PROGRAM_STRING} [--options]\n\nOptions:\n\t

  EOS
  opt :api_host, "The hostname to run the api call against", :default => 'localhost', :type => :string
  opt :console,  "Show the output needed to run the POST in a Rails console", :default => false, :type => :bool
  opt :count, "Adjust the number of request ids (requires the last-requests option)",  :type => :int, :default => 5
  opt :last_requests, "Show a list of the last 5 request ids", :type => :bool
  opt :output,   "The output format (hash, json)", :default => 'hash', :type => :string, :short => '-t'
  opt :password, "The password required for the API request", :default => 'smartvm', :type => :string
  opt :port, "The port listening for the request", :default => 3000, :type => :int, :short => '-n'
  opt :quiet, "Remove verbose output", :default => false, :type => :bool
  opt :request_id, "The Automate request to rerun", :type => :int
  opt :run_it, "Run the api request after outputting the values", :default => false, :type => :bool, :short => '-g'
  opt :ssl, "Use SSL when talking to the API", :default => false, :type => :bool
  opt :username, "The username required for the API request", :default => 'admin', :type => :string
end

if opts[:request_id].nil? && opts[:last_requests].nil?
  Optimist.die :request_id, "must exist as an option"
elsif opts[:last_requests_given] && opts[:count]
  Optimist.die :count, "must be greater than 0" if opts[:count] <= 0
else
  Optimist.die :request_id, "must be a number greater than 0" if opts[:request_id] <= 0
  Optimist.die :output, "must be either hash or json" unless %w(hash json).include?(opts[:output])
end

class Tab
  attr_reader :output, :log

  ARRAY_FIELD_NAMES = [:security_groups].freeze

  def initialize(dialog_content, provision_options, quiet)
    @dialog_content = dialog_content
    @provision_options = provision_options
    @quiet = quiet
    @log = "\n"
    @output = {
      "version"               => "1.1",
      "template_fields"       => {},
      "vm_fields"             => {},
      "requester"             => {},
      "tags"                  => {},
      "additional_values"     => {},
      "ems_custom_attributes" => {},
      "miq_custom_attributes" => {}
    }
    parse_dialog_tabs
  end

  def parse_dialog_tabs
    parse_source

    dialogs = @dialog_content[:dialogs]
    dialogs.keys.each { |tab| process_dialog_tab(tab, dialogs[tab]) }

    # Process Web-service only fields
    ws_only_files
  end

  def parse_source
    src_id = @provision_options.delete(:src_vm_id)
    request_type = @provision_options.delete(:request_type)
    source = VmOrTemplate.find_by(:id => src_id)
    @output["template_fields"] = {'guid' => source.guid, 'name' => source.name, 'request_type' => request_type.to_s}
  end

  def ws_only_files
    @output["additional_values"]      = @provision_options.delete(:ws_values)
    @output["ems_custom_attributes"]  = @provision_options.delete(:ws_ems_custom_attributes)
    @output["miq_custom_attributes"]  = @provision_options.delete(:ws_miq_custom_attributes)
  end

  def dialog_field_values(dialog_tab)
    dialog_tab[:fields].keys.each do |field|
      value = @provision_options[field]
      value = process_list_values(field, value)
      yield(field.to_s, value) if value.present?
      @provision_options.delete(field)
    end
  end

  def process_dialog_tab(tab, dialog_tab)
    unless @quiet
      @log += "Processing tab: #{tab}\n"
      @log += "\n" if tab == 'customize'
    end
    tab_name = respond_to?(tab, true) ? tab : :general_tab
    send(tab_name, tab, dialog_tab)
  end

  def requester(_tab, dialog_tab)
    request = @output["requester"]
    dialog_field_values(dialog_tab) do |field, value|
      request[field] = value
    end
  end

  def purpose(_tab, _dialog_tab)
    request = @output["tags"]
    tag_ids = @provision_options.delete(:vm_tags)
    Classification.where(:id => tag_ids).each do |tag|
      puts "Found tag: #{tag.name} - Adding parent tag: #{tag.parent.name}" unless @quiet
      request[tag.parent.name] = tag.name
    end
  end

  def environment(_tab, dialog_tab)
    request = @output["vm_fields"]
    if @provision_options[:placement_auto].first == true
      request["placement_auto"] = true
      return
    end
    request["placement_auto"] = false

    dialog_field_values(dialog_tab) do |field, value|
      request[field] = value
    end
  end

  def general_tab(_tab, dialog_tab)
    request = @output["vm_fields"]
    dialog_field_values(dialog_tab) do |field, value|
      request[field] = value
    end
  end

  def customize(tab, dialog_tab)
    @provision_options.delete(:customization_template_script)
    general_tab(tab, dialog_tab)
  end

  def schedule(tab, dialog_tab)
    if @provision_options[:schedule_type].first == "immediately"
      @provision_options.delete(:schedule_type)
      @provision_options.delete(:schedule_time)
    else
      @provision_options[:schedule_time] = @provision_options[:schedule_time].to_s
    end
    general_tab(tab, dialog_tab)
  end

  private

  def process_list_values(key, value)
    if ARRAY_FIELD_NAMES.include?(key)
      value
    elsif value.kind_of?(Array)
      value.first
    else
      value
    end
  end
end

class Dialog
  attr_reader :provision_options

  def initialize(provision_options, quiet)
    @quiet = quiet
    @provision_options = provision_options
    load_dialog_content
  end

  def load_dialog_content
    dialog_name = @provision_options.delete(:miq_request_dialog_name)
    @dialog = MiqDialog.find_by(:name => dialog_name)
  end

  def content
    @dialog.content
  end
end

class AutomateHash
  include ActionView::Helpers::TextHelper
  attr_reader :request_id

  URL_PATH = "/api/provision_requests".freeze

  def initialize(request_id, opts)
    @quiet = opts[:quiet]
    @options = opts
    @request_id = request_id
  end

  def last_requests
    list = MiqProvisionRequest.limit(@options[:count]).order(:created_on => 'DESC').map { |x| [x.id, x.description] }
    list_ids = list.map { |x| x[0] }
    if @quiet
      puts list_ids.join(',')
    else
      print "\nSearching for the last #{pluralize(@options[:count], 'request')} run against #{build_url}\n\n"
      print "Found #{pluralize(list.count, 'request')}: #{list_ids.join(',')}\n\n"
      list.each do |part|
        print "#{part[0]} - #{part[1]}\n"
      end
    end
  end

  def perform
    unless @quiet
      print "\nRunning with the following options\n\n"
      pp @options
    end
    hash_output
    console if @options[:console]
    run_it if @options[:run_it]
  end

  def run_it
    print "\nRE Running the Rest API POST to request_id: #{@options[:request_id]}\n\n" unless @quiet
    result = RestClient.post(build_url, output.to_json)
    print "#{result}\n"
  end

  def console
    print "\nPlace in a Rails console to run the POST API call\n" unless @quiet
    print "\nrequire 'rest-client'; RestClient.post '#{build_url}', '#{output.to_json}'\n\n"
  end

  def hash_output
    print log unless @quiet
    puts ""
    if @options[:output] == 'json'
      puts JSON.pretty_generate(output)
    else
      pp output
    end
  end

  def provision_options
    find_request_options
    opts = @provision_options.options.dup.merge!(:request_type => @provision_options.request_type)
    if_pxe_image?(opts) ? strip_out_pxe_klass(opts) : opts
  end

  def dialog
    Dialog.new(provision_options, @quiet)
  end

  def tabs
    Tab.new(dialog.content, provision_options, @quiet)
  end

  def output
    @output ||= tabs.output
  end

  def log
    @log ||= tabs.log
  end

  private

  def if_pxe_image?(opts)
    opts[:pxe_image_id] && opts[:pxe_image_id][0].match("::")
  end

  def strip_out_pxe_klass(opts)
    stripped_value = opts[:pxe_image_id][0].split("::")
    opts[:pxe_image_id][0] = stripped_value.last.to_i
    opts
  end

  def build_url
    @url ||= begin
      url_hash = {:userinfo => "#{@options[:username]}:#{@options[:password]}", :host => @options[:api_host], :port => @options[:port], :path => URL_PATH}
      (@options[:ssl] ? URI::HTTPS : URI::HTTP).build(url_hash).to_s
    end
  end

  def find_request_options
    @provision_options = MiqProvisionRequest.find_by(:id => @request_id)
    return no_provision_found if @provision_options.nil?
    @provision_options
  end

  def no_provision_found
    if @quiet
      print "\nrequest not found\n"
    else
      print "\nCould not find a provision request with id:#{@options[:request_id]}\n\n"
      print "Lookup the last 5 known request ids\n\t"
      print "\n#{PROGRAM_STRING} --last-requests\n\n"
    end
    exit
  end
end

ah = AutomateHash.new(opts[:request_id], opts)
opts[:last_requests_given] ? ah.last_requests : ah.perform
