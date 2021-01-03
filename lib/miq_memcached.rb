require 'runcmd'
require 'linux_admin'

module MiqMemcached
  def self.server_address
    if ENV["MEMCACHED_SERVICE_HOST"] && ENV["MEMCACHED_SERVICE_PORT"]
      "#{ENV["MEMCACHED_SERVICE_HOST"]}:#{ENV["MEMCACHED_SERVICE_PORT"]}"
    else
      ::Settings.session.memcache_server
    end
  end

  # @param options options passed to the memcached client
  # e.g.: :namespace => namespace
  def self.client(options)
    require 'dalli'
    Dalli::Client.new(MiqMemcached.server_address, options)
  end

  class Error < RuntimeError; end
  class ControlError < Error; end

  class Config
    DEFAULT_PORT = 11211
    DEFAULT_USER = 'memcached'
    DEFAULT_MEMORY = 64
    DEFAULT_MAXCONN = 1024
    DEFAULT_OPTIONS = "-l 127.0.0.1"

    def initialize(opts = {})
      update(opts)
    end

    def save(fname)
      File.open(fname, "w") { |f| f.write(@config) }
    end

    def update(opts = {})
      port = opts[:port] || DEFAULT_PORT
      user = opts[:user] || DEFAULT_USER
      memory = opts[:memory] || DEFAULT_MEMORY
      maxconn = opts[:maxconn] || DEFAULT_MAXCONN
      options = opts[:options] || DEFAULT_OPTIONS

      @config = <<-END_OF_CONFIG
PORT="#{port}"
USER="#{user}"
MAXCONN="#{maxconn}"
CACHESIZE="#{memory}"
OPTIONS="#{options}"
END_OF_CONFIG
      @config
    end
  end

  class Control
    include Vmdb::Logging
    #  > memcached -help
    #  memcached 1.4.5
    #  -p <num>      TCP port number to listen on (default: 11211)
    #  -U <num>      UDP port number to listen on (default: 11211, 0 is off)
    #  -s <file>     UNIX socket path to listen on (disables network support)
    #  -a <mask>     access mask for UNIX socket, in octal (default: 0700)
    #  -l <ip_addr>  interface to listen on (default: INADDR_ANY, all addresses)
    #  -d            run as a daemon
    #  -r            maximize core file limit
    #  -u <username> assume identity of <username> (only when run as root)
    #  -m <num>      max memory to use for items in megabytes (default: 64 MB)
    #  -M            return error on memory exhausted (rather than removing items)
    #  -c <num>      max simultaneous connections (default: 1024)
    #  -k            lock down all paged memory.  Note that there is a
    #                limit on how much memory you may lock.  Trying to
    #                allocate more than that would fail, so be sure you
    #                set the limit correctly for the user you started
    #                the daemon with (not for -u <username> user;
    #                under sh this is done with 'ulimit -S -l NUM_KB').
    #  -v            verbose (print errors/warnings while in event loop)
    #  -vv           very verbose (also print client commands/reponses)
    #  -vvv          extremely verbose (also print internal state transitions)
    #  -h            print this help and exit
    #  -i            print memcached and libevent license
    #  -P <file>     save PID in <file>, only used with -d option
    #  -f <factor>   chunk size growth factor (default: 1.25)
    #  -n <bytes>    minimum space allocated for key+value+flags (default: 48)
    #  -L            Try to use large memory pages (if available). Increasing::
    #                the memory page size could reduce the number of TLB misses
    #                and improve the performance. In order to get large pages
    #                from the OS, memcached will allocate the total item-cache
    #                in one large chunk.
    #  -D <char>     Use <char> as the delimiter between key prefixes and IDs.
    #                This is used for per-prefix stats reporting. The default is
    #                ":" (colon). If this option is specified, stats collection
    #                is turned on automatically; if not, then it may be turned on
    #                by sending the "stats detail on" command to the server.
    #  -t <num>      number of threads to use (default: 4)
    #  -R            Maximum number of requests per event, limits the number of
    #                requests process for a given connection to prevent
    #                starvation (default: 20)
    #  -C            Disable use of CAS
    #  -b            Set the backlog queue limit (default: 1024)
    #  -B            Binding protocol - one of ascii, binary, or auto (default)
    #  -I            Override the size of each slab page. Adjusts max item size
    #                (default: 1mb, min: 1k, max: 128m)
    #  -S            Turn on Sasl authentication

    # TODO: Expose all of the constants and get them from the config
    CONF_FILE = '/etc/sysconfig/memcached'

    def self.start(opts = {})
      MiqMemcached::Config.new(opts).save(CONF_FILE)
      LinuxAdmin::Service.new("memcached").start
      _log.info("started memcached with options: #{opts.inspect}")
      true
    end

    def self.stop
      LinuxAdmin::Service.new("memcached").stop
      _log.info("stopped memcached")
    end

    def self.stop!
      stop
      killall
    end

    def self.restart(opts = {})
      stop
      start(opts)
    end

    def self.restart!(opts = {})
      self.stop!
      start(opts)
    end

    def self.killall
      MiqUtil.runcmd("killall -9 memcached")
    rescue AwesomeSpawn::CommandResultError => err
      raise unless err.result.output =~ /memcached: no process/
    end

    def self.status
      begin
        res = MiqUtil.runcmd('service memcached status').to_s.chomp
      rescue AwesomeSpawn::CommandResultError => err
        return false, err.result.output.chomp
      rescue => err
        return false, err.to_s.chomp
      else
        return true, res
      end
      raise "Unknown memcached status: #{res}"
    end
  end
end
