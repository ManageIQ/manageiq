require 'Ext4DirectoryEntry'
require 'Ext4HashTreeHeader'
require 'Ext4HashTreeEntry'

module Ext4

  class Directory

    ROOT_DIRECTORY = 2

    attr_reader :inodeNum

    def initialize(sb, inodeNum = ROOT_DIRECTORY)
      log_prefix = "Ext4::Directory.initialize"
      raise "#{log_prefix}: Nil superblock"   if sb.nil?
      raise "#{log_prefix}: Nil inode number" if inodeNum.nil?
      @sb       = sb
      @inodeNum = inodeNum
      @inodeObj = sb.getInode(inodeNum)
      raise "#{log_prefix}: INODE=#{inodeNum} is NOT a DIRECTORY" unless @inodeObj.isDir?
      @data     = @inodeObj.read
    end

    def globNames
      @ent_names ||= globEntries.collect {|k, v| v.length == 1 ? k : [k] * v.length }.flatten.sort
    end

    def findEntry(name, type = nil)
      return nil unless globEntries.has_key?(name)

      globEntries[name].each do |ent|
        unless @sb.isNewDirEnt?
          inode        = @sb.getInode(ent.inode)
          ent.fileType = inode.fileModeToFileType
        end

        return ent if (ent.fileType == type) || type.nil?
      end
      return nil
    end

    private

    def globEntries
      @ents_by_name ||= globEntriesByLinkedList
    end

    def globEntriesByLinkedList
      ents_by_name = {}
      return ents_by_name if @data.nil?
      newEnt = @sb.isNewDirEnt?
      p = 0
      loop do
        break if p > @data.length - 4
        break if @data[p, 4] == nil
        de = DirectoryEntry.new(@data[p..-1], newEnt)
        raise "Ext4::Directory.globEntriesByLinkedList: DirectoryEntry length cannot be 0" if de.len == 0
        ents_by_name[de.name] ||= []
        ents_by_name[de.name] << de
        p += de.len
      end
      return ents_by_name
    end

    #
    # If the inode has the IF_HASH_INDEX bit set, 
    # then the first directory block is to be interpreted as the root of an HTree index.
    def globEntriesByHashTree
      ents_by_name = {}
      offset = 0
      # Chomp fake '.' and '..' directories first
      2.times do
        de = DirectoryEntry.new(@data[offset..-1], @sb.isNewDirEnt?)
        ents_by_name[de.name] ||= []
        ents_by_name[de.name] << de
        offset += 12
      end
      
$log.info("Ext4::Directory.globEntriesByHashTree (inode=#{@inodeNum}) >>\n#{@data[0,256].hex_dump}")
      header = HashTreeHeader.new(@data[offset..-1])
$log.info("Ext4::Directory.globEntriesByHashTree --\n#{header.dump}")
$log.info("Ext4::Directory.globEntriesByHashTree (inode=#{@inodeNum}) <<#{ents_by_name.inspect}")
      offset += header.length
      root = HashTreeEntry.new(@data[offset..-1], true)
$log.info("Ext4::Directory.globEntriesByHashTree --\n#{root.dump}")
      return ents_by_name
    end

  end #class
end #module
