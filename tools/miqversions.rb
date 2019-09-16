#!/usr/bin/env ruby --disable-gems
#
# When run as a program, prints the following table
#
#     $ tools/miqversions.rb
#     +----------------+------------------------------+------------+-------+-------+------------+
#     | MANAGEIQ       | CLOUDFORMS MANAGEMENT ENGINE | CLOUDFORMS | RUBY  | RAILS | POSTGRESQL |
#     +----------------+------------------------------+------------+-------+-------+------------+
#     |                | 5.1.z                        | 2.0        |       |       |            |
#     |                | 5.2.z                        | 3.0        |       |       |            |
#     | Anand          | 5.3.z                        | 3.1        |       |       |            |
#     | Botvinnik      | 5.4.z                        | 3.1        |       |       |            |
#     | Capablanca     | 5.5.z                        | 4.0        | 2.2.z | 4.2.z | 9.4.z      |
#     | Darga          | 5.6.z                        | 4.1        | 2.2.z | 5.0.z | 9.4.z      |
#     | Euwe           | 5.7.z                        | 4.1        | 2.3.z | 5.0.z | 9.5.z      |
#     | Fine           | 5.8.z                        | 4.5        | 2.3.z | 5.0.z | 9.5.z      |
#     | Gaprindashvili | 5.9.z                        | 4.6        | 2.3.z | 5.0.z | 9.5.z      |
#     | Hammer         | 5.10.z                       | 4.7        | 2.4.z | 5.0.z | 9.5.z      |
#     | Ivanchuk       | 5.11.z                       | 5.0        | 2.5.z | 5.1.z | 10.y       |
#     | Jansa          | 5.12.z                       | 5.1        | 2.5.z | 5.2.z | 10.y       |
#     +----------------+------------------------------+------------+-------+-------+------------+
#
# Otherwise, it can be required in a ruby script or rake task and manipulated as needed:
#
#     require 'tools/miqversions'
#
#     MIQ::Versions.first.cfme_release
#     #=> "5.1.z"
#     MIQ::Versions.first.cloud_forms_release
#     #=> "2.0"
#     MIQ::Versions.last.miq_release
#     #=> "Jansa"
#     MIQ::Versions.last.ruby
#     #=> "2.5.z"
#     MIQ::Versions.last
#     #=> #<struct MIQ::Version miq_release="Jansa", cfme_release="5.12.z", cloud_forms_release="5.1", ruby="2.5.z", rails="5.2.z", postrgresql="10.y">
#

module MIQ
  Version = Struct.new(:miq_release, :cfme_release, :cloud_forms_release, :ruby, :rails, :postrgresql)

  class Versions
    extend Enumerable

    # rubocop:disable Layout/ExtraSpacing, Layout/SpaceAroundOperators, Layout/IndentFirstArrayElement
    # rubocop:disable Layout/SpaceInsideArrayPercentLiteral, Layout/SpaceInsidePercentLiteralDelimiters
    FIELDS   = [
         "MANAGEIQ",      "CLOUDFORMS MANAGEMENT ENGINE", "CLOUDFORMS", "RUBY", "RAILS", "POSTGRESQL"
    ].freeze
    VERSIONS = [
      %w[ N/A              5.1.z                           2.0           N/A     N/A      N/A        ],
      %w[ N/A              5.2.z                           3.0           N/A     N/A      N/A        ],
      %w[ Anand            5.3.z                           3.1           N/A     N/A      N/A        ],
      %w[ Botvinnik        5.4.z                           3.1           N/A     N/A      N/A        ],
      %w[ Capablanca       5.5.z                           4.0           2.2.z   4.2.z    9.4.z      ],
      %w[ Darga            5.6.z                           4.1           2.2.z   5.0.z    9.4.z      ],
      %w[ Euwe             5.7.z                           4.1           2.3.z   5.0.z    9.5.z      ],
      %w[ Fine             5.8.z                           4.5           2.3.z   5.0.z    9.5.z      ],
      %w[ Gaprindashvili   5.9.z                           4.6           2.3.z   5.0.z    9.5.z      ],
      %w[ Hammer           5.10.z                          4.7           2.4.z   5.0.z    9.5.z      ],
      %w[ Ivanchuk         5.11.z                          5.0           2.5.z   5.1.z    10.y       ],
      %w[ Jansa            5.12.z                          5.1           2.5.z   5.2.z    10.y       ]
    ].freeze
    # rubocop:enable Layout/ExtraSpacing, Layout/SpaceAroundOperators, Layout/IndentFirstArrayElement
    # rubocop:enable Layout/SpaceInsideArrayPercentLiteral, Layout/SpaceInsidePercentLiteralDelimiters

    def self.each
      versions.each { |version| yield version }
    end

    def self.last
      versions.last
    end

    def self.[](index)
      versions[index]
    end

    def self.versions
      @versions ||= raw_data.map { |data| Version.new(*data) }
    end

    def self.raw_data
      @raw_data ||= VERSIONS.dup
    end

    def self.print_table
      # Print Header
      puts spacer
      puts printable_row(FIELDS)
      puts spacer

      # Print version data
      raw_data.each do |version|
        version_data = version.map { |column| column == "N/A" ? "" : column } # remove N/A values
        puts printable_row(version_data)
      end
      puts spacer
    end

    def self.printable_row(data)
      "| #{data.map.with_index { |header, index| header.ljust(spacings[index]) }.join(" | ")} |"
    end
    private_class_method :printable_row

    # Column width based on Miq::Versions.raw_data
    def self.spacings
      return @spacings if defined? @spacings

      @spacings = FIELDS.map(&:length)
      raw_data.each do |version|
        version.each.with_index do |col, index|
          @spacings[index] = [@spacings[index].to_i, col.length].max
        end
      end
      @spacings
    end
    private_class_method :spacings

    # Spacer around header and end of raw_data when printing
    def self.spacer
      @spacer ||= "+#{spacings.map { |size| "-" * size + "--" }.join("+")}+"
    end
    private_class_method :spacer
  end
end

# Print the table if this is the program being execute
if $PROGRAM_NAME == __FILE__
  MIQ::Versions.print_table
end
