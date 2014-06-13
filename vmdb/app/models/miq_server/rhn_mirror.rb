require 'linux_admin'

module MiqServer::RhnMirror
  extend ActiveSupport::Concern
  APACHE_MIRROR_CONF_FILE = "/etc/httpd/conf.d/cfme-https-mirror.conf"
  YUM_MIRROR_CONF_FILE    = "/etc/yum.repos.d/cfme-mirror.repo"

  def configure_rhn_mirror_client
    if self.has_assigned_role?("rhn_mirror")
      FileUtils.rm_f(YUM_MIRROR_CONF_FILE)  # Remove the mirror config file if running the mirror server
      $log.info("#{self.class.name}##{__method__} Skipping configuration of mirror client due to this server acting as a mirror server")
      return
    end

    $log.info("#{self.class.name}##{__method__} Configuring RHN Mirror client...")
    MiqServer.my_server.update_attribute(:rhn_mirror, true)
    update_hosts_file
    configure_yum_repo
    $log.info("#{self.class.name}##{__method__} Configuring RHN Mirror client... Complete")
  end

  def resync_rhn_mirror
    $log.info("#{self.class.name}##{__method__} Resync RHN Mirror...")
    $log.error("#{self.class.name}##{__method__} Role: rhn_mirror is not assigned to this server") unless self.has_assigned_role?("rhn_mirror")
    MiqServer.my_server.update_attribute(:rhn_mirror, false)
    configure_rhn_mirror_server
    LinuxAdmin::Yum.download_packages(local_mirror_directory, MiqDatabase.cfme_package_name)
    remove_duplicate_files
    LinuxAdmin::Yum.create_repo(local_mirror_directory)
    $log.info("#{self.class.name}##{__method__} Resync RHN Mirror... Complete")
  end

  private

  def configure_rhn_mirror_server
    $log.info("#{self.class.name}##{__method__} Configuring RHN Mirror server...")
    FileUtils.mkdir_p(local_mirror_directory)
    # TODO: ensure selinux context is properly set on repo directory
    create_apache_vhost
    $log.info("#{self.class.name}##{__method__} Configuring RHN Mirror server... Complete")

    $log.info("#{self.class.name}##{__method__} Queueing RHN Mirror client configuration")
    configure_rhn_mirror_client_queue
  end

  def local_mirror_directory
    "/repo/mirror"
  end

  def apache_mirror_conf
    [ "## CFME SSL Virtual Host Context RHN Mirror",
      "",
      { :directive => "VirtualHost",
        :attribute => "*:443",
        :configurations => [
          "DocumentRoot \"/repo/mirror\"",
          "ServerName #{MiqServer.my_server.guid}",
          "ErrorLog /var/www/miq/vmdb/log/apache/ssl_mirror_error.log",
          "TransferLog /var/www/miq/vmdb/log/apache/ssl_mirror_access_error.log",
          "LogLevel warn",
          "SSLEngine on",
          "SSLProtocol all -SSLv2",
          "SSLCipherSuite ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:!LOW",
          "SSLCertificateFile /var/www/miq/vmdb/certs/server.cer",
          "SSLCertificateKeyFile /var/www/miq/vmdb/certs/server.cer.key",
          "CustomLog /var/www/miq/vmdb/log/apache/ssl_mirror_request.log \"%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \\\"%r\\\" %b\"",
          { :directive => "Directory",
            :attribute => "\"#{local_mirror_directory}\"",
            :configurations => [
              "Options +Indexes",
              "Order allow,deny",
              "Allow from all",
            ]
          }
        ]
      }
    ]
  end

  def create_apache_vhost
    FileUtils.rm_f(APACHE_MIRROR_CONF_FILE)
    status = MiqApache::Conf.create_conf_file(APACHE_MIRROR_CONF_FILE, apache_mirror_conf)

    MiqApache::Control.restart if status
  end

  def configure_yum_repo
    mirrors_servers = MiqServer.order(:ipaddress).select { |s| s.has_assigned_role?("rhn_mirror") }

    if mirrors_servers.blank?
      $log.info("#{self.class.name}##{__method__} No mirror servers found")
    else
      write_yum_repo_file(mirrors_servers)
    end
  end

  def write_yum_repo_file(mirrors_servers)
    file = LinuxAdmin::Yum::RepoFile.create(YUM_MIRROR_CONF_FILE)
    mirrors_servers.each { |server| file.merge!(server.guid => yum_repo_content(server.guid)) }
    file.save
  end

  def yum_repo_content(server_guid)
    { "name"            => "CFME Server #{server_guid}",
      "baseurl"         => "https://#{server_guid}",
      "enabled"         => 1,
      "cost"            => 100,
      "gpgcheck"        => 1,
      "gpgkey"          => "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release",
      "metadata_expire" => 10,
      "sslverify"       => 0,
    }
  end

  def update_hosts_file
    hosts_file = LinuxAdmin::Hosts.new
    MiqServer.order(:ipaddress).each { |server| hosts_file.update_entry(server.ipaddress, server.guid) }
    hosts_file.save
  end

  def configure_rhn_mirror_client_queue
    MiqServer.all.each do |server|
      MiqQueue.put_unless_exists(
        :class_name  => server.class.name,
        :instance_id => server.id,
        :method_name => "configure_rhn_mirror_client",
        :server_guid => server.guid,
        :zone        => server.my_zone
      )
    end
  end

  def remove_duplicate_files
    files = Dir.glob(File.join(local_mirror_directory, "**", "*.rpm"))
    hash  = files.each_with_object({}) do |f, h|
      pkg_name, version = parse_rpm_file_name(f)
      h.store_path(pkg_name, version, f)
    end

    remove_old_versions(hash)
  end

  def remove_old_versions(h, keep = 1)
    $log.info("#{self.class.name}##{__method__} Removing old versions of packages...")

    h.each_value do |versions|
      # TODO: Don't need to v.dup on rubygems v1.8.25 and above
      sorted_versions = versions.keys.map { |v| Gem::Version.new(v.dup) }.sort.map(&:to_s)
      if sorted_versions.length > keep
        keep.times { sorted_versions.pop }
        sorted_versions.each { |v| FileUtils.rm(versions[v]) }
      end
    end

    $log.info("#{self.class.name}##{__method__} Removing old versions of packages... Complete")
  end

  # Example:
  #   parse_rpm_file_name("/repo/mirror/make-3.81-20.el6.x86_64.rpm")
  #   => ["make", "3.81.20"]
  def parse_rpm_file_name(file)
    partitions    = File.basename(file).partition(/[-.][0-9]+/)
    pkg_name      = partitions.shift
    version_array = partitions.join("").gsub("-", ".").split(".").delete_blanks.take_while { |i| i.match(/^\d/) }
    version       = version_array.collect { |i| i.split(/[A-Za-z]/)}.flatten.delete_blanks.join(".")
    [pkg_name, version]
  end
end