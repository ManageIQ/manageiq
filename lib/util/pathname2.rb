# == Synopsis
#
# Pathname2 represents a path name on a filesystem.  A Pathname2 can be
# relative or absolute.  It does not matter whether the path exists or not.
#
# All functionality from File, FileTest, and Dir is included, using a facade
# pattern.
#
# This class works on both Unix and Windows, including UNC path names.  Note
# that forward slashes are converted to backslashes on Windows systems.
#
# == Usage
#
# require "pathname2"
# 
# # Unix
# path1 = Pathname2.new("/foo/bar/baz")
# path2 = Pathname2.new("../zap")
#
# path1 + path2 # "/foo/bar/zap"
# path1.dirname # "/foo/bar"
#
# # Windows
# path1 = Pathname2.new("C:\\foo\\bar\\baz")
# path2 = Pathname2.new("..\\zap")
#
# path1 + path2 # "C:\\foo\\bar\\zap"
# path1.exists? # Does the path exist?
#
# == Author
#
# Daniel J. Berger
# djberg96 at gmail dot com
# imperator on IRC (irc.freenode.net)
#
# == Copyright
# Copyright (c) 2005-2006 Daniel J. Berger.
# Licensed under the same terms as Ruby itself.
#
require 'rubygems'
require 'facade'
require 'fileutils'

class PathnameError < StandardError; end

class Pathname2 < String
   extend Facade
   facade File
   facade Dir

   alias :_plus_ :+ # Used to prevent infinite loops in some cases
   
   if RUBY_PLATFORM.match('mswin') || RUBY_PLATFORM.match('mingw')
      require 'windows/path'
      require 'windows/file'
      include Windows::Path
      include Windows::File
   end

   VERSION  = '1.5.2'
   MAX_PATH = 260
   
   # Creates and returns a new Pathname2 object.
   #
   # On platforms that define File::ALT_SEPARATOR, all forward slashes are
   # replaced with the value of File::ALT_SEPARATOR.  On MS Windows, for
   # example, all forward slashes are replaced with backslashes.
   #
   # File URL's will be converted to Pathname2 objects, e.g. the file URL
   # "file:///C:/Documents%20and%20Settings" will become
   # 'C:\Documents and Settings'.
   #
   def initialize(path)
      if path.length > MAX_PATH
         msg = "string too long.  maximum string length is " + MAX_PATH.to_s
         raise PathnameError, msg
      end

      @sep = File::ALT_SEPARATOR || File::SEPARATOR
      @win = RUBY_PLATFORM.match('mswin') || RUBY_PLATFORM.match('mingw')

      # Handle File URL's.  The separate methods for Windows are necessary
      # because Ruby's URI class does not (currently) parse absolute file URL's
      # properly when they include a drive letter. 
      if @win
         if PathIsURL(path)
            buf = 0.chr * MAX_PATH
            len = [buf.length].pack("l")
            if PathCreateFromUrl(path, buf, len, 0)
               path = buf.strip
            else
               raise PathnameError, "invalid file url: #{path}"
            end
         end
      else
         if path.index('file:///', 0)
            require 'uri'
            path = URI.decode(URI.parse(path).path)
         end
      end

      # Convert forward slashes to backslashes on Windows
      path = path.tr("/", @sep) if @win
      super(path)
   end
	 
   # Returns a real (absolute) pathname of +self+ in the actual filesystem.
   #
   # Unlike most Pathname2 methods, this one assumes that the path actually
   # exists on your filesystem. If it doesn't, an error is raised. If a
   # circular symlink is encountered a system error will be raised.
   #
   def realpath
      File.stat(self) # Check to ensure that the path exists

      if File.symlink?(self)
         file = self.dup

         while true
            file = File.join(File.dirname(file), File.readlink(file))
            break unless File.symlink?(file)
         end

         self.class.new(file).clean
      else
         self.class.new(Dir.pwd) + self
      end
   end
   
   # Returns the children of the directory, files and subdirectories, as an
   # array of Pathname2 objects. If you set +with_directory+ to +false+, then
   # the returned pathnames will contain the filename only.
   #
   # Note that the result never contain the entries '.' and '..' in the
   # the directory because they are not children.  Also note that this method
   # is *not* recursive.
   #
   def children(with_directory = true)
      with_directory = false if self == '.'
      result = []
      Dir.foreach(self) { |file|
         next if file == '.' || file == '..'
         if with_directory
            result << self.class.new(File.join(self, file))
         else
            result << self.class.new(file)
         end
      }
      result
   end

   # Windows only
   #
   # Removes the decoration from a path string.  For example,
   # C:\Path\File[5].txt would become C:\Path\File.txt.  Non-destructive.
   #
   def undecorate
      unless @win
         raise NotImplementedError, "not supported on this platform"
      end
      buf = 0.chr * MAX_PATH
      buf[0..self.length-1] = self
      PathUndecorate(buf)
      self.class.new(buf.split(0.chr).first)
   end
   
   # Windows only
   #
   # Performs the substitution of Pathname2#undecorate in place.
   #
   def undecorate!
      unless @win
         raise NotImplementedError, "not supported on this platform"
      end
      buf = 0.chr * MAX_PATH
      buf[0..self.length-1] = self
      PathUndecorate(buf)
      replace(buf.split(0.chr).first)
      self
   end
   
   # Windows only
   #
   # Returns the short path for a long path name.  For example,
   # C:\Program Files\Java would return C:\Progra~1\Java.
   #
   def short_path
      unless @win
         raise NotImplementedError, "not supported on this platform"
      end
      buf = 0.chr * MAX_PATH
      buf[0..self.length-1] = self
      GetShortPathName(self, buf, buf.length)
      self.class.new(buf.split(0.chr).first)
   end
   
   # Windows only
   #
   # Returns the long path for a long path name.  For example,
   # C:\Progra~1\Java would return C:\Program Files\Java.
   #
   def long_path
      unless @win
         raise NotImplementedError, "not supported on this platform"
      end
      buf = 0.chr * MAX_PATH
      buf[0..self.length-1] = self
      GetLongPathName(self, buf, buf.length)
      self.class.new(buf.split(0.chr).first)
   end
   
   # Removes trailing slash, if present.  Non-destructive.
   #
   def pstrip
      str = self.dup
      if @win
         PathRemoveBackslash(str)
         str.strip!
      else
         if str[-1].chr == @sep
            str.strip!
            str.chop!
         end
      end
      self.class.new(str)
   end
   
   # Removes trailing slash, if present.  Destructive.
   #
   def pstrip!
      if @win
         PathRemoveBackslash(self)
         strip!
      else
         if self[-1].chr == @sep
            strip!
            chop!
         end
      end
      self
   end

   # Splits a pathname into strings based on the path separator.  For example,
   # "/foo/bar/baz" would return a three element array of ['foo','bar','baz'].
   #
   def to_a
      array = split(@sep) # Split string by path separator
      array.delete("")    # Remove empty elements
      array
   end
   
   # Yields each component of the path name to a block.
   #
   def each
      to_a.each{ |element| yield element }
   end

   # Yields each component of the path, concatenating the next component on
   # each iteration, as a new Pathname2 object, starting with the root path.
   #
   # For example, if the path is "/foo/bar/baz", then "/" would be yielded
   # on the first iteration, "/foo" on the second, "/foo/bar on the third and
   # finally "/foo/bar/baz".
   #
   def descend
      if root?
         yield root
         return
      end
   
      if @win
         path = unc? ? "#{root}\\" : ""
      else
         path = absolute? ? root : ""
      end

      # Yield the root directory if an absolute path (and not Windows)
      unless @win && !unc?
         yield root if absolute?
      end

      each{ |element|
         if @win && unc?
            next if root.to_a.include?(element)
         end
         path << element << @sep
         yield self.class.new(path.chop)
      }
   end

   # Yields the path, minus one component on each iteration, as a new
   # Pathname2 object, ending with the root path.
   #
   # For example, if the path is "/foo/bar/baz", then "/foo/bar/baz" would
   # be yielded on the first iteration, "/foo/bar" on the second, "/foo" on
   # the third, and finally "/".
   #
   def ascend
      if root?
         yield root
         return
      end
      
      n = to_a.length

      while n > 0
         path = to_a[0..n-1].join(@sep)
         if absolute?
            if @win && unc?
               path = "\\\\" << path
            end     
            unless @win
               path = root << path
            end
         end

         path = self.class.new(path)
         yield path
         
         if @win && unc?
            break if path.root?
         end
         
         n -= 1
      end

      # Yield the root directory if an absolute path (and not Windows)
      unless @win
         yield root if absolute?
      end
   end

   # Returns the root directory of the path, or '.' if there is no root
   # directory.
   #
   # On Unix, this means the '/' character.  On Windows, this can refer
   # to the drive letter, or the server and share path if the path is a
   # UNC path.
   #
   def root
      dir = "."   
      if @win
         buf = 0.chr * MAX_PATH
         buf[0..self.length-1] = self
      
         if PathStripToRoot(buf)
            dir = buf.split(0.chr).first
         end
      else
         dir = "/" if self =~ /^\//
      end
      self.class.new(dir)
   end

   # Returns whether or not the path consists only of a root directory.
   #
   def root?
      if @win
         PathIsRoot(self)
      else
         self == root
      end
   end
   
   # Windows only
   #
   # Determines if the string is a valid Universal Naming Convention (UNC)
   # for a server and share path.
   #
   def unc?
      unless @win
         raise NotImplementedError, "not supported on this platform"
      end

      PathIsUNC(self)
   end
   
   # Windows only
   #
   # Returns the drive number that corresponds to the root, or nil if not
   # applicable.
   #
   # For example, Pathname2.new("C:\\foo").drive_number would return 2.
   #
   def drive_number
      unless @win
         raise NotImplementedError, "not supported on this platform"
      end

      num = PathGetDriveNumber(self)
      num >= 0 ? num : nil
   end

   # Compares two Pathname2 objects.  Note that Pathnames may only be compared
   # against other Pathnames, not strings.  Otherwise nil is returned.
   #
   def <=>(string)
      return nil unless string.kind_of?(self.class)
      super
   end

   # Returns the parent directory of the given path.
   #
   def parent
      self + ".."
   end

   # Returns a relative path from the argument to the receiver.  If +self+
   # is absolute, the argument must be absolute too.  If +self+ is relative,
   # the argument must be relative too.
   #
   # This method does not access the filesystem.  It assumes no symlinks.
   # You should only compare directories against directories, or files against
   # files, or you may not get expected results.
   #
   # Raises an ArgumentError if it cannot find a relative path.
   #
   def relative_path_from(base)
      base = self.class.new(base) unless base.kind_of?(self.class)

      if self.absolute? != base.absolute?
         raise ArgumentError, "relative path between absolute and relative path"
      end

      return self.class.new(".") if self == base
      return self if base == "."
      
      # Because of the way the Windows version handles Pathname2#clean, we need
      # a little extra help here.
      if @win
         if base == '..' && (self != '..' || self != '.')
            raise ArgumentError, "base directory may not contain '..'"
         end
      end

      dest_arr = self.clean.to_a
      base_arr = base.clean.to_a
      dest_arr.delete('.')
      base_arr.delete('.')

			# Under Windows, check that each path has the same drive name or share name
			if @win
				if self.absolute? && dest_arr[0] != base_arr[0]
					raise ArgumentError, "different prefix: #{self.inspect} and #{base.inspect}"
				end
			end
			
      diff_arr = dest_arr - base_arr

      while !base_arr.empty? && !dest_arr.empty? && base_arr[0] == dest_arr[0]
         base_arr.shift
         dest_arr.shift
      end

      if base_arr.include?("..")
         raise ArgumentError, "base directory may not contain '..'"
      end

      base_arr.fill("..")
      rel_path = base_arr + dest_arr

      if rel_path.empty?
         self.class.new(".")
      else
         self.class.new(rel_path.join(@sep))
      end
   end

   # Adds two Pathname2 objects together, or a Pathname2 and a String.  It
   # also automatically cleans the Pathname2.
   #
   # Example:
   #    path1 = '/foo/bar'
   #    path2 = '../baz'
   #    path1 + path2 # '/foo/baz'
   #
   # Adding a root path to an existing path merely replaces the current
   # path.  Adding '.' to an existing path does nothing.
   #
   def +(string)
      unless string.kind_of?(self.class)
         string = self.class.new(string)
      end

      # Any path plus "." is the same directory
      return self if string == "."
      return string if self == "."
      
      # Use the builtin PathAppend() function if on Windows - much easier
      if @win
         buf = 0.chr * MAX_PATH
         buf[0..self.length-1] = self
         PathAppend(buf, string)
         buf = buf.split("\0").first
         return self.class.new(buf) # PathAppend cleans automatically
      end
      
      # If the string is an absolute directory, return it
      return string if string.absolute?

      array = to_a + string.to_a
      new_string = array.join(@sep)
      
      unless relative? || @win
         temp = @sep + new_string # Add root path back if needed
         new_string.replace(temp)
      end
      
      self.class.new(new_string).clean
   end
   alias :/ :+

   # Returns whether or not the path is an absolute path.
   #
   def absolute?
      !relative?
   end
   
   # Returns whether or not the path is a relative path.
   #
   def relative?
      if @win
         PathIsRelative(self)
      else
         root == "."
      end
   end

   # Removes unnecessary '.' paths and ellides '..' paths appropriately.
   # Non-destructive.
   #
   def clean
      return self if self.empty?

      if @win
         path = 0.chr * MAX_PATH
         if PathCanonicalize(path, self)
            return self.class.new(path.split(0.chr).first)
         else
            return self
         end
      end

      final = []
      to_a.each{ |element|
         next if element == "."
         final.push(element)
         if element == ".." && self != ".."
            2.times{ final.pop }
         end
      }
      final = final.join(@sep)
      final = root._plus_(final) if root != "."
      final = "." if final.empty?
      self.class.new(final)
   end
   alias :cleanpath :clean
   
   # Removes unnecessary '.' paths and ellides '..' paths appropriately.
   # Modifies the receiver in place.
   #
   def clean!
      return self if self.empty?

      if @win
         path = 0.chr * MAX_PATH
         if PathCanonicalize(path, self)
            replace(path.split(0.chr).first)
         end
         return self
      end

      final = []
      to_a.each{ |element|
         next if element == "."
         final.push(element)
         if element == ".." && self != ".."
            2.times{ final.pop }
         end
      }
      final = final.join(@sep)
      final = root + final if root != "."
      final = "." if final.empty?
      replace(self.class.new(final))
      self
   end

   #-- Find facade

   # Pathname2#find is an iterator to traverse a directory tree in a depth first
   # manner. It yields a Pathname2 for each file under the directory passed to
   # Pathname2.new.
   #
   # Since it is implemented by the Find module, Find.prune can be used to
   # control the traverse.
   #
   # If +self+ is ".", yielded pathnames begin with a filename in the current
   # current directory, not ".".
   #
   def find(&block)
      require "find"
      if self == "."
         Find.find(self){ |f| yield self.class.new(f.sub(%r{\A\./}, '')) }
      else
         Find.find(self){ |f| yield self.class.new(f) }
      end
   end

   #-- IO methods not handled by facade
   
   # IO.foreach
   def foreach(*args, &block)
      IO.foreach(self, *args, &block)
   end

   # IO.read
   def read(*args)
      IO.read(self, *args)
   end

   # IO.readlines
   def readlines(*args)
      IO.readlines(self, *args)  
   end

   # IO.sysopen
   def sysopen(*args)
      IO.sysopen(self, *args)
   end

   #-- Dir methods not handled by facade

   # Dir.glob
   #
   # :no-doc:
   # This differs from Tanaka's implementation in that it does a temporary
   # chdir to the path in question, then performs the glob.
   #
   def glob(*args)
      Dir.chdir(self){
         if block_given?
            Dir.glob(*args){ |file| yield self.class.new(file) }
         else
            Dir.glob(*args).map{ |file| self.class.new(file) }
         end
      }
   end

   # Dir.chdir
   def chdir(&block)
      Dir.chdir(self, &block)
   end

   # Dir.entries
   def entries
      Dir.entries(self).map{ |file| self.class.new(file) }
   end

   # Dir.mkdir
   def mkdir(*args)
      Dir.mkdir(self, *args)
   end

   # Dir.opendir
   def opendir(&block)
      Dir.open(self, &block)
   end

   #-- File methods not handled by facade

   # File.chmod
   def chmod(mode)
      File.chmod(mode, self)
   end

   # File.lchmod
   def lchmod(mode)
      File.lchmod(mode, self)
   end

   # File.chown
   def chown(owner, group)
      File.chown(owner, group, self)
   end

   # File.lchown
   def lchown(owner, group)
      File.lchown(owner, group, self)
   end

   # File.fnmatch
   def fnmatch(pattern, *args)
      File.fnmatch(pattern, self, *args)
   end

   # File.fnmatch?
   def fnmatch?(pattern, *args)
      File.fnmatch?(pattern, self, *args)
   end

   # File.link
   def link(old)
      File.link(old, self)
   end

   # File.open
   def open(*args, &block)
      File.open(self, *args, &block)
   end

   # File.rename
   def rename(name)
      File.rename(self, name)
   end

   # File.symlink
   def symlink(old)
      File.symlink(old, self)
   end

   # File.truncate
   def truncate(length)
      File.truncate(self, length)
   end

   # File.utime
   def utime(atime, mtime)
      File.utime(atime, mtime, self)
   end

   # File.basename
   def basename(*args)
      File.basename(self, *args)
   end

   # File.expand_path
   def expand_path(*args)
      File.expand_path(self, *args)
   end

   #--
   # FileUtils facade.  Note that methods already covered by File and Dir
   # are not defined here (pwd, mkdir, etc).
   #++

   # FileUtils.copy
   def copy(*args)
      FileUtils.copy(self, *args)
   end

   # FileUtils.cd
   def cd(*args, &block)
      FileUtils.cd(self, *args, &block)
   end

   # FileUtils.mkdir_p
   def mkdir_p(*args)
      FileUtils.mkdir_p(self, *args)
   end
   alias mkpath mkdir_p

   # FileUtils.ln
   def ln(*args)
      FileUtils.ln(self, *args)
   end

   # FileUtils.ln_s
   def ln_s(*args)
      FileUtils.ln_s(self, *args)
   end

   # FileUtils.ln_sf
   def ln_sf(*args)
      FileUtils.ln_sf(self, *args)
   end

   # FileUtils.cp
   def cp(*args)
      FileUtils.cp(self, *args)
   end

   # FileUtils.cp_r
   def cp_r(*args)
      FileUtils.cp_r(self, *args)
   end

   # FileUtils.mv
   def mv(*args)
      FileUtils.mv(self, *args)
   end

   # FileUtils.rm
   def rm(*args)
      FileUtils.rm(self, *args)
   end
   alias remove rm

   # FileUtils.rm_f
   def rm_f(*args)
      FileUtils.rm_f(self, *args)
   end

   # FileUtils.rm_r
   def rm_r(*args)
      FileUtils.rm_r(self, *args)
   end

   # FileUtils.rm_rf
   def rm_rf(*args)
      FileUtils.rm_rf(self, *args)
   end
   alias rmtree rm_rf

   # FileUtils.install
   def install(*args)
      FileUtils.install(self, *args)
   end

   # FileUtils.touch
   def touch(*args)
      FileUtils.touch(*args)
   end

   # FileUtils.compare_file
   def compare_file(file)
      FileUtils.compare_file(self, file)
   end

   # FileUtils.uptodate?
   def uptodate?(*args)
      FileUtils.uptodate(self, *args)
   end

   # FileUtils.copy_file
   def copy_file(*args)
      FileUtils.copy_file(self, *args)
   end

   # FileUtils.remove_dir
   def remove_dir(*args)
      FileUtils.remove_dir(self, *args)
   end

   # FileUtils.remove_file
   def remove_file(*args)
      FileUtils.remove_dir(self, *args)
   end
   
   # FileUtils.copy_entry
   def copy_entry(*args)
      FileUtils.copy_entry(self, *args)
   end
end

module Kernel
   # Usage: pn{ path } 
   #
   # A shortcut for Pathname2.new
   #
   def pn
      instance_eval{ Pathname2.new(yield) }
   end
end

if $0 == __FILE__
   path1 = '/dev/fd0'
   path2 = 'link2'

   path = Pathname2.new(path1)
   path = path.realpath
   p path
end
