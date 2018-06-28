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

require 'optparse'

module ManageIQ
  module Util
    class FileSplitter
      KILOBYTE = 1024
      MEGABYTE = KILOBYTE * 1024
      GIGABYTE = MEGABYTE * 1024

      BYTE_HASH = {
        "k" => KILOBYTE,
        "m" => MEGABYTE,
        "g" => GIGABYTE
      }.freeze

      attr_accessor :input_file, :byte_count

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
      end

      def split
        until input_file.eof?
          File.open(next_split_filename, "w") do |split_file|
            split_file << input_file.read(byte_count)
            @position += byte_count
          end
        end
      ensure
        input_file.close
      end

      private

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
