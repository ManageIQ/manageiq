#!/usr/bin/env ruby
#
# Helper Script to access the CFME REST API
#
# Makes use of the Trollop and Faraday Client Gems
#   gem install trollop
#   gem install faraday
#   gem install faraday_middleware
#
# Run without options to see the usage.
#
# Globals accessible by loaded test scripts
#

require 'uri'
require 'json'
require 'trollop'
require 'faraday'
require 'faraday_middleware'

api_cmd   = File.basename($PROGRAM_NAME)
api_ver   = "1.0"
cmd_title = "CFME REST API Access Script"

sep       = "_" * 60
prefix    = "/api"
ctype     = "application/json"
scriptdir = ENV['API_SCRIPTDIR'] ? ENV['API_SCRIPTDIR'] : ENV['HOME'] + "/bin"
data      = ""

def msg_exit(msg, exit_code = 1)
  puts msg
  exit exit_code
end

def json_pretty(json)
  puts JSON.pretty_generate(JSON.parse(json))
rescue
  puts json
end

def prompt_get_data
  data = ""
  puts "Enter data to send with request:"
  puts "Terminate with \"\" or \".\""
  s = gets
  loop do
    break if s.nil?
    s = s.strip
    break if s == "." || s == ""
    data << s.strip
    s = gets
  end
  data
end

path      = ""
params    = {}

methods   = {
  "get"    => "get",
  "put"    => "put",
  "post"   => "post",
  "patch"  => "patch",
  "edit"   => "post",
  "create" => "post",
  "update" => "post",
  "delete" => "delete",
}

actions              = methods.keys
methods_needing_data = %w(put post patch)
scriptdir_actions    = %w(ls run)
sub_commands         = actions + %w(edit vi) + scriptdir_actions
api_parameters       = %w(expand attributes limit offset sort_by sort_order sqlfilter by_tag)

opts = Trollop.options do
  version "#{api_cmd} #{api_ver} - #{cmd_title}"
  banner <<-EOS
#{api_cmd} #{api_ver} - #{cmd_title}

Usage: #{api_cmd} [options] <action> [parameters] [resource]

            action - is the action to use for the request, i.e. get, post, patch, edit ...

            [parameters] include: #{api_parameters.join(", ")}
                         specify --help for additional help

            [resource] - is the optional resource i.e. services

       #{api_cmd} [options] vi|edit [script]

            Edit optional api_* scripts. script names must be specified without the
            api_ prefix or .rb suffix. Edits this script if not specified.

       #{api_cmd} [options] run script [method]

            Run optional api_* scripts

       #{api_cmd} [options] ls

            List optional api_* scripts (without the api_ prefix)

#{api_cmd} options are:
EOS
  opt :verbose,    "Verbose mode, show details of the communication",
      :default => false,                    :short => '-v'
  opt :apiversion, "Version of the API to access",
      :default => "",                       :short => '-V'
  opt :url,        "Base URL of CFME to access",
      :default => "http://localhost:3000",  :short => '-l'
  opt :user,       "User to authentication as",
      :default => "admin",                  :short => '-u'
  opt :password,   "Password for user specified to authenticate as",
      :default => "smartvm",                :short => '-p'
  opt :token,      "Token to use for authentication instead of user/password",
      :default => "",                       :short => '-t'
  opt :format,     "How to format Json, pretty|none",
      :default => "pretty",                 :short => '-f'
  opt :inputfile,  "File to use as input to the POST/PUT/PATCH methods",
      :default => "",                       :short => '-i'
  opt :scriptdir,  "Directory where optional api_* scripts live",
      :default => scriptdir,                :short => '-s'
  stop_on sub_commands
end

unless opts[:inputfile].empty?
  Trollop.die :inputfile, "File specified #{opts[:inputfile]} does not exist" unless File.exist?(opts[:inputfile])
end

begin
  URI.parse(opts[:url])
rescue
  Trollop.die :url, "Invalid URL syntax specified #{opts[:url]}"
end

action = ARGV.shift
Trollop.die "Must specify an action" if action.nil?

if scriptdir_actions.include?(action)
  msg_exit("Script directory #{opts[:scriptdir]} does not exist") unless File.directory?(opts[:scriptdir])
end

if action == "ls"
  d = Dir.open(opts[:scriptdir])
  d.each do |file|
    p = file.scan(/^api_(.*)\.rb/)
    puts p unless p.nil?
  end
  d.close
  exit 0
end

if action == "vi" || action == "edit"
  api_script = ARGV.shift
  if api_script.nil? || api_script == ""
    api_script_file = File.expand_path($PROGRAM_NAME)
  else
    api_script_file = File.join(opts[:scriptdir], "api_#{api_script}.rb")
  end
  ed_cmd = "vi"
  ed_cmd = ENV["EDITOR"] if action == "edit" && ENV["EDITOR"]
  cmd = "#{ed_cmd} #{api_script_file}"
  system(cmd)
  exit 0
end

if action == "run"
  script = ARGV.shift
  method = ARGV.shift
  msg_exit("Must specify a script to run.") if script.nil?
  api_script = "#{opts[:scriptdir]}/api_#{script}.rb"
  msg_exit("Script file #{api_script} does not exist") unless File.exist?(api_script)
else
  api_params = Trollop.options do
    api_parameters.each { |param| opt param.intern, param, :default => "" }
  end
  api_parameters.each { |param| params[param] = api_params[param.intern] unless api_params[param.intern].empty? }
end

if action != "run"
  resource = ARGV.shift

  resource = "/" + resource             if resource && resource[0] != "/"
  resource = resource.gsub(prefix, '')  unless resource.nil?

  method = methods[action]
  msg_exit("Unsupported action #{action} specified") if method.nil?

  if methods_needing_data.include?(method)
    data = opts[:inputfile].empty? ? prompt_get_data : File.read(opts[:inputfile])

    msg_exit("Action #{action} requires data to be specified") if data.empty?
  end
end

conn = Faraday.new(:url => opts[:url], :ssl => {:verify => false}) do |faraday|
  faraday.request(:url_encoded)               # form-encode POST params
  faraday.response(:logger) if opts[:verbose] # log requests to STDOUT
  faraday.use FaradayMiddleware::FollowRedirects, :limit => 3, :standards_compliant => true
  faraday.adapter(Faraday.default_adapter)    # make requests with Net::HTTP
  faraday.basic_auth(opts[:user], opts[:password]) if opts[:token].empty?
end

if action == "run"
  puts "Loading #{api_script}"
  require api_script
  as = ApiScript.new(ctype, conn)
  puts "Running #{api_script} with method #{method} ..."
  method.nil? ? as.run : as.run(method)
  exit
end

path = prefix
path << "/v#{opts[:apiversion]}" unless opts[:apiversion].empty?

collection = ""
item = ""
unless resource.nil?
  path << resource
  rscan = resource.scan(/[^\/]+/)
  collection, item = rscan[0..1]
end

if opts[:verbose]
  puts sep
  puts "Connection Endpoint: #{opts[:url]}"
  puts "Action:              #{action}"
  puts "HTTP Method:         #{method}"
  puts "Resource:            #{resource}"
  puts "Collection:          #{collection}"
  puts "Item:                #{item}"
  puts "Parameters:"
  params.keys.each { |k| puts "#{' ' * 21}#{k} = #{params[k]}" }
  puts "Path:                #{path}"
  puts "Data:                #{data}"
end

begin
  response = conn.send(method) do |req|
    req.url path
    req.headers[:content_type]  = ctype
    req.headers[:accept]        = ctype
    req.headers['X-Auth-Token'] = opts[:token] unless opts[:token].empty?
    req.params.merge!(params)
    req.body = data if methods_needing_data.include?(method)
  end
rescue => e
  msg_exit("\nFailed to connect to #{opts[:url]} - #{e}")
end

if opts[:verbose]
  puts sep
  puts "Response Headers:"
  puts response.headers

  puts sep
  puts "Response Body:"
end

if response.body
  body = response.body.strip
  if opts[:format] == "pretty"
    puts json_pretty(body) unless body.empty?
  else
    puts body
  end
end

exit response.status >= 400 ? 1 : 0
