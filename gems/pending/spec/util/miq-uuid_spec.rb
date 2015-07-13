require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. util})))
require 'miq-uuid'

describe MiqUUID do
  MIQ_UUID_CASES = [
    'valid guid lower case', '01234567-89ab-cdef-abcd-ef0123456789', '01234567-89ab-cdef-abcd-ef0123456789',
    'valid guid upper case', '01234567-89AB-CDEF-abcd-ef0123456789', '01234567-89ab-cdef-abcd-ef0123456789',
    'valid guid but invalid structure', '01 23 45 67 89 AB CD EF-AB CD EF 01 23 45 67 89', '01234567-89ab-cdef-abcd-ef0123456789',
    
    'nil',     nil,          nil,
    'blank',   '',           nil,
    'garbage', 'sdkjfLSDLK', nil,

    'valid structure but garbage', 'sdkjfLSD-LKJF-8367-41df-FLKD209alkfd',  nil,
    'mostly valid but garbage',    '01234567-89AB-CDEF-abcd-efgggggggggg',  nil,
    'valid chars but too long',    '01234567-89AB-CDEF-abcd-ef0123456789a', nil,
    'valid chars but too short',   '01234567-89AB-CDEF-abcd-ef012345678',   nil,
   ]

  MIQ_UUID_CASES.each_slice(3) do |title, value, expected|
    it(".clean_guid with #{title}") { MiqUUID.clean_guid(value).should == expected }
  end

  it ".new_guid" do
    guid = MiqUUID.new_guid
    guid.should be_kind_of String
    guid.should match MiqUUID::REGEX_FORMAT
  end

  it ".parse_raw" do
    guid = MiqUUID.parse_raw("\001#Eg\211\253\315\357\253\315\357\001#Eg\211")
    guid.should be_kind_of UUIDTools::UUID
    guid.to_s.should == '01234567-89ab-cdef-abcd-ef0123456789'
  end
end
