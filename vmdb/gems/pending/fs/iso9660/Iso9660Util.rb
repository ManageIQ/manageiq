# encoding: US-ASCII

require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Iso9660Util
	
	ISO_DATE = BinaryStruct.new([
		'a4',	'year',		# Absolute year.
		'a2',	'month',
		'a2',	'day',
		'a2',	'hour',
		'a2',	'min',
		'a2',	'sec',
		'a2',	'hun',
		'c',	'offset'	# 15-min intervals (iow 4 per time zone).
	])
	
	ISO_DATE_SHORT = BinaryStruct.new([
		'C',	'year',		# Since 1900.
		'C',	'month',
		'C',	'day',
		'C',	'hour',
		'C',	'min',
		'C',	'sec',
		'c',	'offset'	# 15-min intervals.
	])
	
	def Iso9660Util.IsoToRubyDate(isodate)
		begin
			tv = OpenStruct.new(ISO_DATE.decode(isodate))
		rescue
			return Time.at(0).gmtime
		end
		Time.gm(tv.sec, tv.min, tv.hour, tv.day, tv.month, tv.year, nil, nil, nil, tv.offset / 4)
	end
	
	def Iso9660Util.GetTimezone(isodate)
		isodate[16, 1].unpack('c')[0] / 4
	end
	
	def Iso9660Util.IsoShortToRubyDate(isoShort)
		return Time.at(0).gmtime if isoShort == "\0" * 7
		begin
			tv = OpenStruct.new(ISO_DATE_SHORT.decode(isoShort))
		rescue
			return Time.at(0).gmtime
		end
		Time.gm(tv.sec, tv.min, tv.hour, tv.day, tv.month, tv.year + 1900, nil, nil, nil, tv.offset / 4)
	end
	
	def Iso9660Util.GetShortTimezone(isoShort)
		isoShort[7] / 4
	end
end
