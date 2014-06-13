require 'Iso9660DirectoryEntry'

$:.push("#{File.dirname(__FILE__)}/../util")
require 'binary_struct'

module Iso9660
	
	class Directory
		
		# Find entry flags.
		FE_DIR = 0
		FE_FILE = 1
		FE_EITHER = 2
		
		# System Use Sharing Protocol header (for Rock Ridge in this implementation).
		SUSP = BinaryStruct.new([
			'a2',	'signature',
			'C',	'len',
			'C',	'version',
			'n',	'check',
			'C',	'skip_bytes'
		])
		SUSP_SIGNATURE	= "SP"
		SUSP_SIZE				= 7
		SUSP_VERSION		= 1
		SUSP_CHECK_WORD	= 0xbeef
		
		attr_reader :myEnt, :susp
		
		def initialize(bs, thisEntry)
			raise "Boot sector is nil." if bs.nil?
			raise "No directory entry specified." if thisEntry.nil?
			raise "Given entry is not a DirectoryEntry" if thisEntry.class.to_s != "Iso9660::DirectoryEntry"
			
			@bs = bs
			@myEnt = thisEntry
			@data = getDirData
			
			# Check for RockRidge extensions.
			@susp = checkRockRidge(DirectoryEntry.new(@data, @bs.suff))
		end
		
		def getDirData
			@bs.getSectors(@myEnt.fileStart, @myEnt.fileSize / @bs.sectorSize)
		end
		
		def globNames
			names = Array.new
			globEntries.each do |de| names << de.name end
			return names
		end
		
		def findEntry(name, flags = FE_EITHER)
			# TODO: enable flags
			globEntries.each do |de|
				return de if de.name == name				# Joliet & RR are case sensitive.
				return de if de.name == name.upcase	# ISO 9660 is ucase only.
			end
			return nil
		end
		
		def globEntries
			# Prep flag bits.
			flags = EXT_NONE
			flags |= EXT_JOLIET if @bs.isJoliet?
			flags |= EXT_ROCKRIDGE if @susp
			
			# Glob entries.
			entries = Array.new
			offset = 0
			loop do
				de = DirectoryEntry.new(@data[offset..-1], @bs.suff, flags)
				break if de.length == 0
				entries << de
				# Debugging only.
				#puts "#{de.dump}\n"
				offset += de.length
			end
			return entries
		end
		
		def checkRockRidge(de)
			if de.sua
				susp = SUSP.decode(de.sua)
				return nil if susp['signature'] != SUSP_SIGNATURE
				return nil if susp['len'] != SUSP_SIZE
				return nil if susp['check'] != SUSP_CHECK_WORD
				raise "System Use Sharing Protocol version mismatch" if susp['version'] != SUSP_VERSION
				return susp
			end
			return nil
		end
		
	end #class
end #module
