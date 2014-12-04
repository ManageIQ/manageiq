require 'Ext3FileData'
require 'Ext3DirectoryEntry'

module Ext3
	
	class Directory
		
		ROOT_DIRECTORY = 2
		
		def initialize(sb, inodeNum = ROOT_DIRECTORY)
			raise "Ext3::Directory.initialize: Nil superblock"   if sb.nil?
			raise "Ext3::Directory.initialize: Nil inode number" if inodeNum.nil?
			@sb = sb; @inodeNum = inodeNum
			@inodeObj = sb.getInode(inodeNum)
			@data = FileData.new(@inodeObj, @sb).read
		end
		
		def globNames
      @ent_names ||= globEntries.keys.compact.sort
		end
		
		def findEntry(name, type = nil)
      return nil unless globEntries.has_key?(name)

      newEnt = @sb.isNewDirEnt?
      globEntries[name].each do |ent|
        ent.fileType = @sb.getInode(ent.inode).fileModeToFileType if not newEnt
        return ent if ent.fileType == type or type == nil
      end
      return nil
		end
		
		private
		
		def globEntries
      return @ents_by_name unless @ents_by_name.nil?

			@ents_by_name = {}; p = 0
			return @ents_by_name if @data.nil?
			newEnt = @sb.isNewDirEnt?
			loop do
			  break if p > @data.length - 4
				break if @data[p, 4] == nil
				de = DirectoryEntry.new(@data[p..-1], newEnt)
        raise "Ext3::Directory.globEntries: DirectoryEntry length cannot be 0" if de.len == 0
        @ents_by_name[de.name] ||= []
        @ents_by_name[de.name] << de
				p += de.len
			end
			return @ents_by_name
		end
		
	end #class
end #module
