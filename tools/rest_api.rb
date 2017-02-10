#!/usr/bin/env ruby
#
# Helper Script to access the ManageIQ REST API
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

class RestApi
  VERSION = "2.4.0-pre".freeze
  API_CMD = File.basename($PROGRAM_NAME)

  class Cli
    METHODS = {
      "get"     => "get",
      "put"     => "put",
      "post"    => "post",
      "patch"   => "patch",
      "edit"    => "post",
      "create"  => "post",
      "update"  => "post",
      "delete"  => "delete",
      "options" => "options",
    }.freeze

    SEP       = ("_" * 60).freeze
    PREFIX    = "/api".freeze
    CTYPE     = "application/json".freeze
    SCRIPTDIR = ENV['API_SCRIPTDIR'] ? ENV['API_SCRIPTDIR'] : ENV['HOME'] + "/bin".freeze

    ACTIONS              = METHODS.keys
    METHODS_NEEDING_DATA = %w(put post patch).freeze
    SCRIPTDIR_ACTIONS    = %w(ls run).freeze
    SUB_COMMANDS         = ACTIONS + %w(edit vi) + SCRIPTDIR_ACTIONS
    API_PARAMETERS       = %w(expand hide attributes decorators limit offset
                              depth search_options
                              sort_by sort_order sort_options
                              filter by_tag provider_class collection_class requester_type).freeze

    MULTI_PARAMS         = %w(filter).freeze

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
      while (s = gets)
        s = s.strip
        break if s == "." || s == ""
        data << s
      end
      data
    end

    def script_filename(scriptdir, filename)
      filename &&= filename.strip
      return if filename.nil? || filename == ""
      filename = "api_#{filename}" unless filename =~ /^api_/
      filename = "#{filename}.rb" unless filename =~ /\.rb$/
      File.join(scriptdir, filename)
    end

    def run
      data      = ""
      params    = {}

      opts = Trollop.options do
        version "#{API_CMD} #{VERSION} - ManageIQ REST API Access Script"
        banner <<-EOS
      #{version}

      Usage: #{API_CMD} [options] <action> [parameters] [resource]

                  action - is the action to use for the request, i.e. get, post, patch, edit ...

                  [parameters] include: #{API_PARAMETERS.join(", ")}
                               specify --help for additional help

                  [resource] - is the optional resource i.e. services

             #{API_CMD} [options] vi|edit [script]

                  Edit optional api_*.rb scripts.

             #{API_CMD} [options] run script [method]

                  Run optional api_* scripts

             #{API_CMD} [options] ls

                  List optional api_* scripts (without the api_ prefix)

      #{API_CMD} options are:
      EOS
        opt :verbose,    "Verbose mode, show details of the communication",
            :default => false,                    :short => '-v'
        opt :apiversion, "Version of the API to access",
            :default => "",                       :short => '-V'
        opt :url,        "Base URL of Appliance to access",
            :default => "http://localhost:3000",  :short => '-l'
        opt :user,       "User to authenticate as",
            :default => "admin",                  :short => '-u'
        opt :group,      "User group to authorize as",
            :default => "",                       :short => '-g'
        opt :password,   "Password for user specified to authenticate as",
            :default => "smartvm",                :short => '-p'
        opt :token,      "Token to use for authentication instead of user/password",
            :default => "",                       :short => '-t'
        opt :miqtoken,   "Token to use for system authentication",
            :default => "",                       :short => '-m'
        opt :format,     "How to format Json, pretty|none",
            :default => "pretty",                 :short => '-f'
        opt :inputfile,  "File to use as input to the POST/PUT/PATCH methods",
            :default => "",                       :short => '-i'
        opt :scriptdir,  "Directory where optional api_* scripts live",
            :default => SCRIPTDIR,                :short => '-s'
        stop_on SUB_COMMANDS
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

      if SCRIPTDIR_ACTIONS.include?(action)
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
        api_script_file = script_filename(opts[:scriptdir], ARGV.shift) || File.expand_path($PROGRAM_NAME)
        ed_cmd = "vi"
        ed_cmd = ENV["EDITOR"] if action == "edit" && ENV["EDITOR"]
        cmd = "#{ed_cmd} #{api_script_file}"
        system(cmd)
        exit 0
      end

      if action == "run"
        script = ARGV.shift
        method = ARGV.shift
        api_script = script_filename(opts[:scriptdir], script)
        msg_exit("Must specify a script to run.") if api_script.nil?
        msg_exit("Script file #{api_script} does not exist") unless File.exist?(api_script)
      else
        api_params = Trollop.options do
          norm_options  = {:default => ""}
          multi_options = {:default => "", :multi => true}
          API_PARAMETERS.each { |p| opt p.intern, p, (MULTI_PARAMS.include?(p) ? multi_options.dup : norm_options.dup) }
        end
        API_PARAMETERS.each do |param|
          if MULTI_PARAMS.include?(param)
            params[param] = api_params[param.intern] unless api_params[param.intern].all?(&:empty?)
          else
            params[param] = api_params[param.intern] unless api_params[param.intern].empty?
          end
        end
      end

      if action != "run"
        resource = ARGV.shift

        resource = "/" + resource             if resource && resource[0] != "/"
        resource = resource.gsub(PREFIX, '')  unless resource.nil?

        method = METHODS[action]
        msg_exit("Unsupported action #{action} specified") if method.nil?

        if METHODS_NEEDING_DATA.include?(method)
          data = opts[:inputfile].empty? ? prompt_get_data : File.read(opts[:inputfile])

          msg_exit("Action #{action} requires data to be specified") if data.empty?
        end
      end

      conn = Faraday.new(:url => opts[:url], :ssl => {:verify => false}) do |faraday|
        faraday.request(:url_encoded)               # form-encode POST params
        faraday.response(:logger) if opts[:verbose] # log requests to STDOUT
        faraday.use FaradayMiddleware::FollowRedirects, :limit => 3, :standards_compliant => true
        faraday.adapter(Faraday.default_adapter)    # make requests with Net::HTTP
        faraday.basic_auth(opts[:user], opts[:password]) if opts[:token].empty? && opts[:miqtoken].empty?
      end

      if action == "run"
        puts "Loading #{api_script}"
        require api_script
        as = ApiScript.new(CTYPE, conn)
        puts "Running #{api_script} with method #{method} ..."
        method.nil? ? as.run : as.run(method)
        exit
      end

      path = PREFIX.dup
      path << "/v#{opts[:apiversion]}" unless opts[:apiversion].empty?

      collection = ""
      item = ""
      unless resource.nil?
        path << resource
        rscan = resource.scan(%r{[^/]+})
        collection, item = rscan[0..1]
      end

      if opts[:verbose]
        puts SEP
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
        response = conn.run_request(method.to_sym, path, nil, nil) do |req|
          req.headers[:content_type]  = CTYPE
          req.headers[:accept]        = CTYPE
          req.headers['X-MIQ-Group']  = opts[:group] unless opts[:group].empty?
          req.headers['X-MIQ-Token']  = opts[:miqtoken] unless opts[:miqtoken].empty?
          req.headers['X-Auth-Token'] = opts[:token] unless opts[:token].empty?
          req.params.merge!(params)
          req.body = data if METHODS_NEEDING_DATA.include?(method)
        end
      rescue => e
        msg_exit("\nFailed to connect to #{opts[:url]} - #{e}")
      end

      if opts[:verbose]
        puts SEP
        puts "Response Headers:"
        puts response.headers

        puts SEP
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
    end
  end
end
RestApi::Cli.new.run
