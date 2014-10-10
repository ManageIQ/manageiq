# encoding: US-ASCII

require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util win32})))
require 'wim_parser'

require 'time'

describe WimParser do
  WIM_PARSER_DATA_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'data'))

  before(:each) do
    @wim_parser = WimParser.new(File.join(WIM_PARSER_DATA_DIR, "tiny.wim"))
  end

  context "#header" do
    it "with a WIM file" do
      @wim_parser.header.should == {
        "image_tag"                   => "MSWIM\0\0\0",
        "size"                        => 208,
        "version"                     => 68864,
        "flags"                       => 0x00020082,
        "compression_size"            => 32768,
        "wim_guid"                    => "N\x91-\xF7a'\x8D@\x9A0\xC5\xF1~\xD7X\x16", # real GUID is pending adding support for winnt.h GUID structure parsing
        "part_number"                 => 1,
        "total_parts"                 => 1,
        "image_count"                 => 2,
        "offset_table_size"           => 150,
        "offset_table_flags"          => 0x02000000,
        "offset_table_offset"         => 2254,
        "offset_table_original_size"  => 150,
        "xml_data_size"               => 1644,
        "xml_data_flags"              => 0x02000000,
        "xml_data_offset"             => 2404,
        "xml_data_original_size"      => 1644,
        "boot_metadata_size"          => 0,
        "boot_metadata_flags"         => 0x00000000,
        "boot_metadata_offset"        => 0,
        "boot_metadata_original_size" => 0,
        "boot_index"                  => 0,
        "integrity_size"              => 0,
        "integrity_flags"             => 0x00000000,
        "integrity_offset"            => 0,
        "integrity_original_size"     => 0,
        "unused"                      => ("\0" * 60),
      }
    end

    it "with a non-WIM file" do
      w = WimParser.new(__FILE__)
      lambda { w.header }.should raise_error
    end
  end

  it "#xml_data" do
    @wim_parser.xml_data.should == {
      "total_bytes" => 2404,
      "images" => [
        {
          "index"                  => 1,
          "name"                   => "Nothing",
          "description"            => "Empty Windows Disk",
          "dir_count"              => 3,
          "file_count"             => 0,
          "total_bytes"            => 0,
          "hard_link_bytes"        => 0,
          "creation_time"          => Time.parse("2012-09-01 04:05:53 UTC"),
          "last_modification_time" => Time.parse("2012-09-01 04:05:53 UTC"),
        },
        {
          "index"                  => 2,
          "name"                   => "appended image",
          "description"            => "some files added",
          "dir_count"              => 5,
          "file_count"             => 1,
          "total_bytes"            => 4,
          "hard_link_bytes"        => 0,
          "creation_time"          => Time.parse("2012-09-01 04:08:59 UTC"),
          "last_modification_time" => Time.parse("2012-09-01 04:08:59 UTC"),
        },
      ]
    }
  end
end
