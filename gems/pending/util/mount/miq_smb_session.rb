require 'miq_generic_mount_session'

class MiqSmbSession < MiqGenericMountSession
  PORTS = [445, 139]

  def initialize(log_settings)
    super(log_settings.merge(:ports => PORTS) )
    raise "username is a required value!" if @settings[:username].nil?
    raise "password is a required value!" if @settings[:password].nil?
  end

  def connect
    scheme, userinfo, @host, port, registry, @mount_root, opaque, query, fragment = URI.split(URI.encode(@settings[:uri]) )
    @mount_path = @mount_root.split("/")[0..1].join("/")
    super
  end

  def mount_root
    File.join(@mnt_point, (@mount_root.split("/") - @mount_path.split("/")))
  end

  def mount_share
    super

    log_header = "MIQ(#{self.class.name}-mount_share)"
    # Convert backslashes to slashes in case the username is in domain\username format
    @settings[:username]= @settings[:username].gsub('\\','/')

    # To work around 2.6.18 kernel issue where a domain could be passed along incorrectly if not specified, explicitly provide both the username and domain (set the domain 'null' if not provided)
    # https://bugzilla.samba.org/show_bug.cgi?id=4176
    split_username = @settings[:username].split('/')
    case split_username.length
    when 1
      # No domain provided
      user = split_username.first
      domain = 'null'
    when 2
      domain, user = split_username
    else
      raise "Expected 'domain/username' or 'domain\\username' format, received: '#{@settings[:username]}'"
    end

    self.logger.info("#{log_header} Connecting to host: [#{@host}], share: [#{@mount_path}], domain: [#{domain}], user: [#{user}], using mount point: [#{@mnt_point}]...")
    # mount -t cifs //192.168.252.140/temp /media/windows_share/ -o rw,username=jrafaniello,password=blah,domain=manageiq.com

    # Quote the hostname and share and username since they have spaces in it
    self.runcmd("mount -t cifs '//#{File.join(@host, @mount_path)}' #{@mnt_point} -o rw,username='#{user}',password='#{@settings[:password]}',domain='#{domain}'")
    self.logger.info("#{log_header} Connecting to host: [#{@host}], share: [#{@mount_path}]...Complete")
  end
end
