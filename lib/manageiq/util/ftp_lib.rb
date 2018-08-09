require 'net/ftp'
require 'logger'

# Helper methods for net/ftp based classes and files.
#
# Will setup a `@ftp` attr_accessor to be used as the return value for
# `.connect`, the main method being provided in this class.  Will also setup
# logging if not already done for the particular class (that follows the
# VmdbLogger conventions, and setup a `uri` attr_accessor if that doesn't
# already exist.
module ManageIQ
  module Util
    module FtpLib
      def self.included(klass)
        klass.send(:attr_accessor, :ftp)

        klass.send(:attr_accessor, :uri)  unless klass.instance_methods.include?(:uri=)

        unless klass.instance_methods.include?(:_log)
          klass.send(:define_method, :_log) do
            self.class.instance_logger
          end
        end
      end

      def connect(cred_hash = nil)
        host = URI(uri).hostname

        begin
          host_url = host
          host_url << " (#{name})" if respond_to?(:name)
          _log.info("Connecting to FTP host #{host_url}...")
          @ftp         = Net::FTP.new(host)
          # Use passive mode to avoid firewall issues see http://slacksite.com/other/ftp.html#passive
          @ftp.passive = true
          # @ftp.debug_mode = true if settings[:debug]  # TODO: add debug option
          creds = cred_hash ? [cred_hash[:username], cred_hash[:password]] : login_credentials
          @ftp.login(*creds)
          _log.info("Successfully connected FTP host #{host_url}...")
        rescue SocketError => err
          _log.error("Failed to connect.  #{err.message}")
          raise
        rescue Net::FTPPermError => err
          _log.error("Failed to login.  #{err.message}")
          raise
        else
          @ftp
        end
      end

      def file_exists?(file_or_directory)
        !ftp.nlst(file_or_directory.to_s).empty?
      rescue Net::FTPPermError
        false
      end

      private

      def create_directory_structure(directory_path)
        pwd = ftp.pwd
        directory_path.to_s.split('/').each do |directory|
          unless ftp.nlst.include?(directory)
            _log.info("creating #{directory}")
            ftp.mkdir(directory)
          end
          ftp.chdir(directory)
        end
        ftp.chdir(pwd)
      end
    end
  end
end
