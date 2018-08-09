#!/usr/bin/env ruby
#
# Yes, you guessed it... this is basically the `split` command...
#
# The intent of this is to allow for greater flexibility and utility than is
# provided by the BSD/GNU variants however, specifically allowing to pipe from
# a pg_dump directly to a upload target (whether it be a mounted volume or
# something like a FTP endpoint, though the former is basically already
# supported with vanilla `split`).
#
# FTP, specifically, will be supported natively since ruby has Net::FTP support
# built in (feature WIP).  This also allows for this to work correctly cross
# platform, without having to be concerned with differences in `split`
# functionality.

require_relative 'ftp_lib'
require 'optparse'

module ManageIQ
  module Util
    class FileSplitter
      include ManageIQ::Util::FtpLib

      KILOBYTE = 1024
      MEGABYTE = KILOBYTE * 1024
      GIGABYTE = MEGABYTE * 1024

      BYTE_HASH = {
        "k" => KILOBYTE,
        "m" => MEGABYTE,
        "g" => GIGABYTE
      }.freeze

      attr_accessor :input_file, :byte_count

      class << self
        attr_writer :instance_logger

        # Don't log by default, but allow this to work with FtpLib logging.
        def instance_logger
          @instance_logger ||= Logger.new(File::NULL)
        end
      end

      def self.run(options = nil)
        options ||= parse_argv
        new(options).split
      end

      def self.parse_argv
        options = {}
        OptionParser.new do |opt|
          opt.on("-b", "--byte-count=BYTES", "Number of bytes for each split") do |bytes|
            options[:byte_count] = parse_byte_value(bytes)
          end
          opt.on("--ftp-host=HOST", "Host of the FTP server") do |host|
            options[:ftp_host] = host
          end
          opt.on("--ftp-dir=DIR", "Dir on the FTP server to save files") do |dir|
            options[:ftp_dir] = dir
          end
          opt.on("-v", "--verbose", "Turn on logging") do
            options[:verbose] = logging
          end
        end.parse!

        input_file, file_pattern = determine_input_file_and_file_pattern

        options[:input_file]     = input_file
        options[:input_filename] = file_pattern

        options
      end

      def initialize(options = {})
        @input_file     = options[:input_file] || ARGF
        @input_filename = options[:input_filename]
        @byte_count     = options[:byte_count] || (10 * MEGABYTE)
        @position       = 0

        setup_logging(options)
        setup_ftp(options)
      end

      def split
        until input_file.eof?
          if ftp
            split_ftp
          else
            split_local
          end
          @position += byte_count
        end
      ensure
        input_file.close
        ftp.close if ftp
      end

      private

      def setup_logging(options)
        self.class.instance_logger = Logger.new(STDOUT) if options[:verbose]
      end

      def setup_ftp(options)
        if options[:ftp_host]
          @uri      = options[:ftp_host]
          @ftp_user = options[:ftp_user] || ENV["FTP_USERNAME"] || "anonymous"
          @ftp_pass = options[:ftp_pass] || ENV["FTP_PASSWORD"]
          @ftp      = connect

          @input_filename = File.join(options[:ftp_dir] || "", File.basename(input_filename))
        end
      end

      def login_credentials
        [@ftp_user, @ftp_pass]
      end

      def split_local
        File.open(next_split_filename, "w") do |split_file|
          split_file << input_file.read(byte_count)
        end
      end

      # Specific version of Net::FTP#storbinary that doesn't use an existing local
      # file, and only uploads a specific size from the input_file
      FTP_CHUNKSIZE = ::Net::FTP::DEFAULT_BLOCKSIZE
      def split_ftp
        ftp_mkdir_p
        ftp.synchronize do
          ftp.send(:with_binary, true) do
            conn         = ftp.send(:transfercmd, "STOR #{next_split_filename}")
            buf_left     = byte_count
            while buf_left.positive?
              cur_readsize = buf_left - FTP_CHUNKSIZE >= 0 ? FTP_CHUNKSIZE : buf_left
              buf = input_file.read(cur_readsize)
              break if buf == nil # rubocop:disable Style/NilComparison (from original)
              conn.write(buf)
              buf_left -= FTP_CHUNKSIZE
            end
            conn.close
            ftp.send(:voidresp)
          end
        end
      rescue Errno::EPIPE
        # EPIPE, in this case, means that the data connection was unexpectedly
        # terminated.  Rather than just raising EPIPE to the caller, check the
        # response on the control connection.  If getresp doesn't raise a more
        # appropriate exception, re-raise the original exception.
        getresp
        raise
      end

      def ftp_mkdir_p
        dir_path = File.dirname(input_filename)[1..-1].split('/') - ftp.pwd[1..-1].split("/")
        create_directory_structure(dir_path.join('/'))
      end

      def input_filename
        @input_filename ||= File.expand_path(input_file.path)
      end

      def next_split_filename
        "#{input_filename}.#{'%05d' % (@position / byte_count + 1)}"
      end

      def self.parse_byte_value(bytes)
        match = bytes.match(/^(?<BYTE_NUM>\d+)(?<BYTE_QUALIFIER>K|M|G)?$/i)
        raise ArgumentError, "Invalid byte-count", [] if match.nil?

        bytes = match[:BYTE_NUM].to_i
        if match[:BYTE_QUALIFIER]
          bytes *= BYTE_HASH[match[:BYTE_QUALIFIER].downcase]
        end
        bytes
      end
      private_class_method :parse_byte_value

      def self.determine_input_file_and_file_pattern
        input_file   = ARGV.shift
        file_pattern = nil

        case input_file
        when "-"
          input_file = nil
        else
          if input_file && File.exist?(input_file)
            input_file = File.open(input_file)
          else
            file_pattern, input_file = input_file, nil
          end
        end
        file_pattern ||= ARGV.shift
        raise ArgumentError, "must pass a file pattern if piping from STDIN" if file_pattern.nil? && input_file.nil?

        [input_file, file_pattern]
      end
      private_class_method :determine_input_file_and_file_pattern
    end
  end
end

ManageIQ::Util::FileSplitter.run if $PROGRAM_NAME == __FILE__
