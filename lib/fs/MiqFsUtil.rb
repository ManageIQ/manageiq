require 'find'
require 'fileutils'
require 'yaml'
require 'ostruct'
require 'zlib'

$: << "#{File.dirname(__FILE__)}/.."

class MiqFsUtil
    
    attr_accessor :verbose, :fromFs, :toFs
    
    def initialize(fromFs, toFs, us=nil)
		setUpdateSpec(us)
		@fromFs	= fromFs
		@toFs	= toFs
        
        @verbose = false
    end

	def updateSpec=(us)
		setUpdateSpec(us)
	end

	def setUpdateSpec(us)
		if us
	        @csa = us
	        @csa = YAML.load_file(us) if @csa.kind_of? String
	        @csa = [@csa] if @csa.kind_of? Hash
	        raise "Invalid collection spec" if !@csa.kind_of? Array
		else
			@csa = nil
		end
	end
	
	#
	# Load the update spec from a file in the fromFs.
	#
	def loadUpdateSpec(path)
		@fromFs.fileOpen(path) { |fo| @csa = YAML.load(fo.read) }
	end
    
    def update
		raise "MiqFsUpdate.update: no current update spec" if !@csa
        @csa.each { |cs| doUpdate(OpenStruct.new(cs)) }
    end
    
    def dumpSpec(specFile)
		raise "MiqFsUpdate.dumpSpec: no current update spec" if !@csa
        YAML.dump(@csa, File.open(specFile, "w"))
    end

	#
    # Copy files and directories from fromFs to the toFs.
    #
    # FILE -> FILE
    # FILE -> DIR
    # DIR  -> DIR (recursive = true)
    #
    def copy(from, to, recursive=false)
        allTargets = []
		from = [ from ] if !from.kind_of?(Array)
        from.each { |t| allTargets.concat(dirGlob(t)) }
        
        raise "copy: no source files matched" if allTargets.length == 0
        if (allTargets.length > 1 || recursive)
            raise "copy: destination directory does not exist" if !@toFs.fileExists?(to)
            raise "copy: destination must be a directory for multi-file copy" if !@toFs.fileDirectory?(to)
        end
            
        allTargets.each do |f|
			owd = @fromFs.pwd
			@fromFs.chdir(File.dirname(f))
			f = File.basename(f)
			
            #
            # Copy plain files.
            #
            if @fromFs.fileFile?(f)
                if @toFs.fileDirectory?(to)
                    tf = File.join(to, File.basename(f))
                else
                    tf = to
                end
                copySingle(f, tf)
                next
            end
            
            #
            # If the recursive flag is not set, skip directories.
            #
            next if !recursive
            
            #
            # Recursively copy directory sub-tree.
            #
            @fromFs.chdir(f)
            td = File.join(to, f)
            @toFs.dirMkdir(td) if !@toFs.fileExists?(td)
            @fromFs.findEach('.') do |ff|
                tf = File.join(td, ff)
                if @fromFs.fileDirectory?(ff)
                    @toFs.dirMkdir(tf)
                elsif @fromFs.fileFile?(ff)
                    copySingle(ff, tf)
                end
            end # findEach
            @fromFs.chdir(owd)
        end # allTargets.each
    end
    
private

	def log_puts(str="")
		if $log
			$log.info str
		else
			puts str
		end
	end

	GLOB_CHARS = '*?[{'
	def isGlob?(str)
	    str.count(GLOB_CHARS) != 0
	end

	def dirGlob(glb, *flags, &block)
	    return([glb]) if !isGlob?(glb)
	    
	    if glb[0,1] == '/'
	        dir = '/'
	        glb = glb[1..-1]
	    else
	        dir = @fromFs.pwd
	    end
	    
	    matches = doGlob(glb.split('/'), dir, flags)
		return(matches) if !block_given?
		
		matches.each do |e|
			block.call(e) 
		end
		return(false)
	end
	
	def doGlob(glbArr, dir, flags)
	    return [] if !glbArr || glbArr.length == 0

	    retArr = []
	    glb = glbArr[0]
	    
	    dirForeach(dir) do |e|
	        if flags.length == 0
				match = File.fnmatch(glb, e)
			else
				match = File.fnmatch(glb, e, flags)
			end
			if match
			    if glbArr.length == 1
			        retArr << File.join(dir, e)
			    else
			        next if !@fromFs.fileDirectory?(nf = File.join(dir, e))
			        retArr.concat(doGlob(glbArr[1..-1], nf, flags))
			    end
			end
	    end
	    return(retArr)
	end

	def copySingle(ff, tf)
		if @verbose
			log_puts "Copying: #{ff}"
			log_puts "     to: #{tf}"
		end
        @fromFs.fileOpen(ff) do |ffo|
            tfo = @toFs.fileOpen(tf, "wb")
            while (buf = ffo.read(1024))
                tfo.write(buf)
            end
            tfo.close
        end
    end
    
    def doUpdate(cs)        
        #
        # The directory where the collection will be created.
        #
        destDir = cs.todir

		#
		# Save the current directory.
		#
		fowd = @fromFs.pwd
		towd = @toFs.pwd

		begin
	        #
	        # The directory relative to which the files will be collected.
	        #
	        @fromFs.chdir(cs.basedir)
        
	        #
	        # Loop through the files and directories that are to be included in the collection.
	        #
	        cs.include.each do |i|
	            raise "File: #{i} does not exist" if !@fromFs.fileExists? i
	            #
	            # If this is a plain file, then include it in the collection.
	            #
	            if !@fromFs.fileDirectory? i
	                toFile = File.join(destDir, i)
	                makePath(File.dirname(toFile))
	                #
	                # If the file path matches an encrypt RE and doesn't
	                # match a noencrypt RE, then encrypt the contents of
	                # the file before copying it to the collection.
	                #
	                if cs.encrypt && cs.encrypt.detect { |e| i =~ e }
	                    if !cs.noencrypt || !cs.noencrypt.detect { |ne| i =~ ne }
							compressFile(i, toFile)
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
	            @fromFs.findEach(i) do |path|
	                #
	                # Prune directories that match an exclude RE.
	                #
	                if @fromFs.fileDirectory? path
	                    @fromFs.findEachPrune if cs.exclude && cs.exclude.detect { |e| path =~ e }
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
							compressFile(path, toFile)
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

			#
			# Remove files from the destination fs.
			#
			@toFs.chdir(destDir)
			cs.remove.each do |r|
				if r.kind_of? Regexp
					#
					# If the entry is a RE, then remove all files and directories in
					# the destination directory that match the RE>
					#
					@toFs.findEach(".") do |p|
						next if !r.match(p)
						
						log_puts "\tRemoving: #{p}" if @verbose
						if !@toFs.fileDirectory? p
							@toFs.fileDelete(p)
						else
							@toFs.rmBranch(p)
							@toFs.findEachPrune
						end
					end
				else
					#
					# If the entry is a string, then it should be the path to the file
					# or directory to be removed.
					#
					if !@toFs.exists? r
						log_puts "Remove file: #{i} does not exist" if @verbose
						next
					end
			
					log_puts "\tRemoving: #{r}" if @verbose
					if !@toFs.fileDirectory? r
						@toFs.fileDelete(r)
					else
						@toFs.rmBranch(r)
					end
				end
			end if cs.remove
		ensure
			@fromFs.chdir(fowd)
			@toFs.chdir(towd)
		end
    end
    
    def makePath(path)
        return if @toFs.fileExists? path
        parentDir = @toFs.fileDirname(path)
        makePath(parentDir) if !@toFs.fileExists? parentDir
        @toFs.dirMkdir(path)
    end
    
    def copyFile(src, dest)
		if @fromFs.respond_to?(:hasTag?) && @fromFs.hasTag?(src, "compressed")
			decompressFile(src, dest)
			return
		end
		
		if @verbose
	        log_puts "\t    COPY: #{src}"
			log_puts "\t      TO: #{dest}"
		end
        @fromFs.fileOpen(src) do |ffo|
            tfo = @toFs.fileOpen(dest, "wb")
            while (buf = ffo.read(4096))
                tfo.write(buf, buf.length)
            end
            tfo.close
        end
    end
    
    def compressFile(src, dest)
		if @verbose
	        log_puts "\tCOMPRESS: #{src}"
			log_puts "\t      TO: #{dest}"
		end
        @fromFs.fileOpen(src) do |ffo|
            tfo = @toFs.fileOpen(dest, "wb")
            zipper = Zlib::Deflate.new
            while (buf = ffo.read(4096))
                zipper << buf
            end
            tfo.write(zipper.deflate(nil, Zlib::FINISH))
            tfo.addTag("compressed") if tfo.respond_to?(:addTag)
            tfo.close
        end
    end

	def decompressFile(src, dest)
		if @verbose
	        log_puts "\tDECOMPRESS: #{src}"
			log_puts "\t      TO: #{dest}"
		end
        @fromFs.fileOpen(src) do |ffo|
            tfo = @toFs.fileOpen(dest, "wb")
			unzipper = Zlib::Inflate.new 
            while (buf = ffo.read(4096))
                unzipper << buf
            end
            tfo.write(unzipper.inflate(nil))
            tfo.close
        end
    end
    
end # class MiqFsUpdate
