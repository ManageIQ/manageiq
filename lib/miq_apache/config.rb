module MiqApache
  DEFAULT_ROOT_DIR = '/'
  DEFAULT_SERVICE_NAME = 'httpd'
  DEFAULT_PACKAGE_NAME = 'httpd'

  def self.root_dir
    ENV.fetch('MIQ_APACHE_ROOT_DIR', DEFAULT_ROOT_DIR)
  end

  def self.service_name
    ENV.fetch('MIQ_APACHE_SERVICE_NAME', DEFAULT_SERVICE_NAME)
  end

  def self.package_name
    ENV.fetch('MIQ_APACHE_PACKAGE_NAME', DEFAULT_PACKAGE_NAME)
  end
end
