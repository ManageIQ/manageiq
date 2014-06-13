require 'stringio'

require 'Fat32DirectoryEntry'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'MiqMemory'

# ////////////////////////////////////////////////////////////////////////////
# // Data definitions.

# A Directory is basically a helper for dealing with directories. It doesn't
# really have a structure of it's own, but builds structure when it needs to
# using DirectoryEntry instances.

# ////////////////////////////////////////////////////////////////////////////
# // Class.

module Fat32

	class Directory
		
		# Maximum LFN entry span in bytes (LFN entries *can* span clusters).
		MAX_ENT_SIZE = 640
		
		# Find entry flags.
		FE_DIR = 0
		FE_FILE = 1
		FE_EITHER = 2
		
		# Get free entry behaviors.
		# Windows 98 returns the first deleted or unallocated entry.
		# Windows XP returns the first unallocated entry.
		# Advantage W98: less allocation, advantage WXP: deleted entries are not overwritten.
		GF_W98 = 0
		GF_WXP = 1
		
		# Initialization
		def initialize(bs, cluster = nil)
			raise "Nil boot sector" if bs == nil
			cluster = bs.rootCluster if cluster == nil
			
			@bs = bs
			# Allocate one cluster if cluster is zero.
			cluster = @bs.allocClusters(0) if cluster == 0
			@cluster = cluster
			@data, @all_clusters = getDirData()
		end
		
		# ////////////////////////////////////////////////////////////////////////////
		# // Class helpers & accessors.
	  
		# Return all names in directory as a sorted string array.
		def globNames()
			names = Array.new
			cluster = @cluster
			mf = StringIO.new(@bs.getCluster(cluster))
			loop do
				(@bs.bytesPerCluster / DIR_ENT_SIZE - 1).times {
					de = DirectoryEntry.new(mf.read())
					break if de.name == ''
					names << de.name.downcase if de.name !=
						DirectoryEntry::AF_DELETED && de.name[0] != DirectoryEntry::AF_DELETED
					mf = StringIO.new(de.unused)
					break if mf.size == 0
				}
				data = @bs.getNextCluster(cluster)
				break if data == nil
				cluster = data[0]
				mf = StringIO.new(data[1])
			end
			return names.sort!
		end
		
		# Return a DirectoryEntry for a specific file (or subdirectory).
		def findEntry(name, flags = FE_EITHER)
			de = nil #found directory entry.
			skip_next = found = false
			offset = 0
			
			# Look for appropriate records.
			0.step(@data.length - 1, DIR_ENT_SIZE) {|offset|
				
				# Check allocation status (ignore if deleted, done if not allocated).
				alloc_flags = @data[offset]
				next if alloc_flags == DirectoryEntry::AF_DELETED
				break if alloc_flags == DirectoryEntry::AF_NOT_ALLOCATED
				
				# Skip LFN entries unless it's the first (last iteration already chewed them all up).
				attrib = @data[offset + ATTRIB_OFFSET]
				if attrib == DirectoryEntry::FA_LFN && (alloc_flags & DirectoryEntry::AF_LFN_LAST != DirectoryEntry::AF_LFN_LAST)
					# Also skip the next entry (it's the base entry for the last dir ent).
					skip_next = true; next
				end
				if skip_next
					skip_next = false; next
				end
				
				# If a specific type of record was requested, look for only that type.
				# NOTE: You know, it's possible to look ahead and see what the base entry is.
				if flags != FE_EITHER && attrib != DirectoryEntry::FA_LFN
					next if flags == FE_DIR  && (attrib & DirectoryEntry::FA_DIRECTORY == 0)
					next if flags == FE_FILE && (attrib & DirectoryEntry::FA_DIRECTORY != 0)
				end
				
				# Potential match... get a DirectoryEntry & stop if found.
				de = DirectoryEntry.new(@data[offset, MAX_ENT_SIZE])
				# TODO - what if the name ends with a dot & there's another dot in the name?
				if de.name.downcase == name.downcase || de.shortName.downcase == name.downcase
					found = true
					break
				end
			}
			return nil if not found
			parentLoc = offset.divmod(@bs.bytesPerCluster)
			de.parentCluster = @all_clusters[parentLoc[0]].number
			de.parentOffset = parentLoc[1]
			return de
		end
		
		def mkdir(name)
			dir = createFile(name)
			data = FileData.new(dir, @bs)
			dir.setAttribute(DirectoryEntry::FA_ARCHIVE, false)
			dir.setAttribute(DirectoryEntry::FA_DIRECTORY)
			dir.writeEntry(@bs)
			
			# Write dot and double dot directories.
			dot = DirectoryEntry.new; dotdot = DirectoryEntry.new;
			dot.name = "."; dotdot.name = ".."
			dot.setAttribute(DirectoryEntry::FA_ARCHIVE, false)
			dot.setAttribute(DirectoryEntry::FA_DIRECTORY)
			dotdot.setAttribute(DirectoryEntry::FA_ARCHIVE, false)
			dotdot.setAttribute(DirectoryEntry::FA_DIRECTORY)
			buf = dot.raw + dotdot.raw
			data.write(buf)
			dir.firstCluster = data.firstCluster
			dir.writeEntry(@bs)
			
			# Update firsCluster in . and .. (if .. is root then it's 0, not 2).
			dot.firstCluster = dir.firstCluster
			dotdot.firstCluster = dir.parentCluster == 2 ? 0 : dir.parentCluster
			buf = dot.raw + dotdot.raw
			data.rewind
			data.write(buf)
		end
		
		def createFile(name)
			de = DirectoryEntry.new; de.name = name
			while findEntry(de.shortName) != nil do
				raise "Duplicate file name: #{de.shortName}" if not de.shortName.include?("~")
				de.incShortName
			end
			de.parentOffset, de.parentCluster = getFirstFreeEntry(de.numEnts)
			de.writeEntry(@bs)
			@data, @all_clusters = getDirData()
			return de
		end
		
		# ////////////////////////////////////////////////////////////////////////////
		# // Utility functions.
		
		# Get free entry or entries in directory data. If not exist, allocate cluster.
		def getFirstFreeEntry(num_entries = 1, behavior = GF_W98)
			0.step(@data.size - 1, DIR_ENT_SIZE) do |offset|
				next if (@data[offset] != DirectoryEntry::AF_NOT_ALLOCATED and @data[offset] != DirectoryEntry::AF_DELETED)
				num = countFreeEntries(behavior, @data[offset..-1])
				return offset.divmod(@bs.bytesPerCluster)[1], getClusterStatus(offset).number if num >= num_entries
			end
			
			# Must allocate another cluster.
			cluster = @bs.allocClusters(@cluster)
			@data += MiqMemory.create_zero_buffer(@bs.bytesPerCluster)
			@all_clusters << mkClusterStatus(cluster, 0)
			return 0, cluster
		end
		
		# Return the number of contiguous free entries starting at buf[0] according to behavior.
		def countFreeEntries(behavior, buf)
			num_free = 0
			0.step(buf.size - 1, DIR_ENT_SIZE) do |offset|
				if isFree(buf[offset], behavior)
					num_free += 1
				else
					return num_free
				end
			end
			return num_free
		end
		
		def isFree(allocStatus, behavior)
			if behavior == GF_W98
				return true if allocStatus == DirectoryEntry::AF_NOT_ALLOCATED || allocStatus == DirectoryEntry::AF_DELETED
			elsif behavior == GF_WXP
				return true if allocStatus == DirectoryEntry::AF_NOT_ALLOCATED
			else
				raise "Fat32Directory#isFree: Unknown behavior: #{behavior}"
			end
			return false
		end
		
		def getDirData
			allClusters = []
			clus = @cluster
			allClusters << mkClusterStatus(clus, 0)
			buf = @bs.getCluster(clus); data = nil
			while (data = @bs.getNextCluster(clus)) != nil
				clus = data[0]; buf += data[1]
				allClusters << mkClusterStatus(clus, 0)
			end
			return buf, allClusters
		end
	
		# TODO - Loose this idea.
		def mkClusterStatus(num, dirty)
			status = OpenStruct.new
			status.number = num
			status.dirty = dirty
			return status
		end
		
		def getClusterStatus(offset)
			idx = offset.divmod(@bs.bytesPerCluster)[0]
			return @all_clusters[idx]
		end
	end
end # module Fat32
