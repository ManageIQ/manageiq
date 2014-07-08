require 'fileutils'
require 'util/miq-password'
require 'tempfile'

module ApplianceConsole
  class CertificateAuthority
    CA_SCRIPTS      = "/var/www/miq/ca"
    TEMPLATES       = "/var/www/miq/system/TEMPLATE/"

    CFME_DIR        = "/var/www/miq/vmdb/certs"
    PSQL_CLIENT_DIR = "/root/.postgresql"
    CA_DIR          = "/var/www/miq/ca/root"

    CA_SIGN         = "#{CA_SCRIPTS}/so_sign.sh"
    CA_CREATE       = "bash #{CA_SCRIPTS}/so_ca.sh"
    CA_ROOT         = "#{CA_SCRIPTS}/root"

    # local hostname and ip address
    attr_accessor :host, :ip

    attr_accessor :cahost, :causer
    attr_accessor :company

    def initialize(host = nil, ip = nil)
      @host     = host
      @ip       = ip
    end

    def remote(cahost, causer)
      @cahost     = cahost
      @causer     = causer
      self
    end

    def local(company)
      company = "/O=#{company}" unless company.include?("/O=")
      self.company = company
      self
    end

    def local?
      !!company
    end

    def local_dir?
      File.exist?(CA_ROOT)
    end

    def run
      tmp_file = Tempfile.new(%w(cert_auth .tgz))
      begin
        fetch [
          "OU=postgres client #{ip}/CN=root", "postgresql",
          "OU=restclient/CN=#{ip}",           "apiclient",
          "OU=restserver/CN=#{ip}",           "apiserver",
          "OU=postgres/CN=#{ip}",             "postgres"
        ], tmp_file.path

        extract(tmp_file.path, "root", %w(root.crt apiclient.crt apiclient.key apiserver.crt apiserver.key), CFME_DIR)
        # local system already has keys, so only extract if not a local ca
        extract(tmp_file.path, "root", 'v*_key*', CFME_DIR) unless local?
        FileUtils.mkdir_p(PSQL_CLIENT_DIR, :mode => 700)
        extract(tmp_file.path, "root", %w(root.crt postgresql.crt postgresql.key), PSQL_CLIENT_DIR)
        extract(tmp_file.path, "postgres.postgres", %w(postgres.crt postgres.key), CFME_DIR)
        # the ca's root certificate is publically viewable (postgres server needs to view it)
        FileUtils.chmod 0622 , "CFME_DIR/root.crt"

        # now that there are certs, enable port 8443
        FileUtils.cp("#{TEMPLATES}/etc/httpd/conf.d/cfme-https-cert.conf", "/etc/httpd/conf.d/cfme-https-cert.conf")
      ensure
        tmp_file.unlink
      end
    end

    def fetch(args, target_file)
      if local?
        fetch_local(args, target_file)
      else
        fetch_remote(args, target_file)
      end
    end

    # not packaging up keys
    def fetch_local(args, target_file)
      AwesomeSpawn.run!(CA_SIGN, :params => {"-r" => CA_ROOT, "-t" => target_file, "-c" => 'root.crt', nil => args})
    end

    # packaging up keys
    # streaming over ssh, to a local file
    def fetch_remote(args, target_file)
      cmd = AwesomeSpawn.build_command_line(CA_SIGN, "-r" => CA_ROOT, "-t" => "-", "-c" => 'root.crt', "-k" => nil, nil => args)
      system("(ssh #{causer}@#{cahost} '#{cmd}') > #{target_file}")
    end

    def create
      raise "Create only works on a local company" unless local?
      AwesomeSpawn.run!(CA_CREATE, :params => {"-r" => CA_ROOT, "-C" => company})
      self
    end

    # currently duplicated in KeyConfiguration. this will leave here once we go to a different ca
    # dump the files into the approperiate directory
    def extract(tar_name, owner, files, target_dir)
      AwesomeSpawn.run!("tar", :params => {"-xzf" => tar_name, "-C" => target_dir, nil => files})
      Array(files).each do |file|
        Dir["#{target_dir}/#{file}"].each do |file_with_path|
          FileUtils.chmod 0600, file_with_path
          FileUtils.chown owner.split(".").first, owner.split(".")[1], file_with_path if owner
          AwesomeSpawn.run!("/sbin/restorecon", :params => {"-v" => file_with_path})
        end
      end
    end
  end
end
