require 'find'
require 'fileutils'
require 'yaml'
require 'ostruct'
require 'zlib'

$: << "#{File.dirname(__FILE__)}/.."
$: << "#{File.dirname(__FILE__)}/../../MiqFS"

require "MiqFS"
require "MetakitFS"

class MkCollectFiles
    
    attr_writer :verbose
    
    def initialize(collectionSpec, mkFile)
        @csa = collectionSpec
        @csa = YAML.load_file(collectionSpec) if @csa.kind_of? String
        @csa = [@csa] if @csa.kind_of? Hash
        raise "Invalid collection spec" if !@csa.kind_of? Array
        
        dobj = OpenStruct.new
        dobj.mkfile = mkFile
        dobj.create = true
        @mkFS = MiqFS.new(MetakitFS, dobj)
        
        @verbose = false
    end
    
    def collect
        @csa.each { |cs| doCollect(OpenStruct.new(cs)) }
    end
    
    def dumpSpec(specFile)
        YAML.dump(@csa, File.open(specFile, "w"))
    end
    
private
    
    def doCollect(cs)        
        #
        # The directory where the collection will be created.
        #
        destDir = cs.todir

        #
        # The directory relative to which the files will be collected.
        #
        Dir.chdir(cs.basedir)
        puts "BASEDIR: #{Dir.pwd}" if @verbose
        
        #
        # Loop through the files and directories that are to be included in the collection.
        #
        cs.include.each do |i|
            raise "File: #{i} does not exist" if !File.exist? i
            #
            # If this is a plain file, then include it in the collection.
            #
            if !File.directory? i
                puts "FILE: #{i}" if @verbose
                toFile = File.join(destDir, i)
                makePath(File.dirname(toFile))
                #
                # If the file path matches an encrypt RE and doesn't
                # match a noencrypt RE, then encrypt the contents of
                # the file before copying it to the collection.
                #
                if cs.encrypt && cs.encrypt.detect { |e| i =~ e }
                    if !cs.noencrypt || !cs.noencrypt.detect { |ne| i =~ ne }
                        encryptFile(i, toFile)
                        next
                    end
                end
                #
                # If the file path matches an compress RE and doesn't
                # match a nocompress RE, then compress the contents of
                # the file before copying it to the collection.
                #
                if cs.compress && cs.compress.detect { |e| i =~ e }
                    if !cs.nocompress || !cs.nocompress.detect { |ne| i =~ ne }
                        compressFile(i, toFile)
                        next
                    end
                end
                copyFile(i, toFile)
                next
            end

            #
            # If this is a directory, then recursively copy its contents
            # to the collection directory.
            #
            puts "DIR: #{i}" if @verbose
            Find.find(i) do |path|
                #
                # Prune directories that match an exclude RE.
                #
                if File.directory? path
                    Find.prune if cs.exclude && cs.exclude.detect { |e| path =~ e }
                    next
                end
                #
                # Skip files that match an exclude RE.
                #
                next if cs.exclude && cs.exclude.detect { |e| path =~ e }
                toFile = File.join(destDir, path)
                makePath(File.dirname(toFile))
                #
                # If the file path matches an encrypt RE and doesn't
                # match a noencrypt RE, then encrypt the contents of
                # the file before copying it to the collection.
                #
                if cs.encrypt && cs.encrypt.detect { |e| path =~ e }
                    if !cs.noencrypt || !cs.noencrypt.detect { |ne| path =~ ne }
                        encryptFile(path, toFile)
                        next
                    end
                end
                #
                # If the file path matches an compress RE and doesn't
                # match a nocompress RE, then compress the contents of
                # the file before copying it to the collection.
                #
                if cs.compress && cs.compress.detect { |e| path =~ e }
                    if !cs.nocompress || !cs.nocompress.detect { |ne| path =~ ne }
                        compressFile(path, toFile)
                        next
                    end
                end
                copyFile(path, toFile)
            end
        end if cs.include 
    end
    
    def makePath(path)
        return if @mkFS.fileExists? path
        parentDir = @mkFS.fileDirname(path)
        makePath(parentDir) if !@mkFS.fileExists? parentDir
        @mkFS.dirMkdir(path)
    end
    
    def copyFile(src, dest)
        puts "\t    COPY: #{src}\n\t      TO: #{dest}\n\n" if @verbose
        File.open(src) do |ffo|
            tfo = @mkFS.fileOpen(dest, "wb")
            while (buf = ffo.read(4096))
                tfo.write(buf, buf.length)
            end
            tfo.close
        end
    end
    alias_method :encryptFile, :copyFile
    
    def compressFile(src, dest)
        puts "\tCOMPRESS: #{src}\n\t      TO: #{dest}\n\n" if @verbose
        File.open(src) do |ffo|
            tfo = @mkFS.fileOpen(dest, "wb")
            zipper = Zlib::Deflate.new
            while (buf = ffo.read(4096))
                zipper << buf
            end
            tfo.write(zipper.deflate(nil, Zlib::FINISH))
            tfo.addTag("compressed")
            tfo.close
        end
    end
    
end # class MkCollectFiles
