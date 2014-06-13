$:.push("#{File.dirname(__FILE__)}/../../util")
$:.push("#{File.dirname(__FILE__)}/../../db/MiqBdb")

require 'miq-hash_struct'
require 'miq-xml'
require 'MiqRpmPackages'
require 'MiqConaryPackages'

module MiqLinux
    
    class Packages
        
        attr_accessor :fs
        #
        # Debian based packageing.
        # 
        DPKG_FILE   = '/var/lib/dpkg/status'
        #
        # Gentoo based packageing - portage.
        # 
        PORTAGE_DB  = '/var/db/pkg'
        PORTAGE_CMD = '/usr/bin/emerge'

        #
        # RPM DB directory.
        #
        RPM_DB = "/var/lib/rpm"
        
        #
        # Conary DB file
        #
        CONARY_FILE = "/var/lib/conarydb/conarydb"
        
        def initialize(fs=nil)
            @fs = fs
            @pkg = nil
            @packages = []
            
            return if !fs
            
            if fs.fileExists?(DPKG_FILE)
                procDpkg(DPKG_FILE)
            elsif fs.fileExists?(PORTAGE_CMD) && fs.fileDirectory?(PORTAGE_DB)
                procPortage(PORTAGE_DB)
            elsif fs.fileDirectory?(RPM_DB)
                procRPM(RPM_DB)
            elsif fs.fileExists?(CONARY_FILE)
                procConary(CONARY_FILE)
            end
        end
        
        def procDpkg(pf)
            $log.debug "Processing Dpkg package database"
            pfls = ""
            @fs.fileOpen(pf) { |fo| pfls = fo.read }
            desc = false
            
            pfls.each_line do |pfl|
                pfl.chop!
                
                case pfl
                    when /^Package:\s/ then
                        @pkg = MiqHashStruct.new
                        @pkg.name = pfl.gsub(/^Package:\s/, '')
                        @packages << @pkg
                        desc = false
                        
                    when /^Status:\s/ then
                        @pkg.status = pfl.gsub(/^Status:\s/, '')
                        @pkg.installed = false
                        @pkg.installed = true if @pkg.status =~ /\sinstalled$/
                        desc = false

                    when /^Version:\s/ then
                        @pkg.version = pfl.gsub(/^Version:\s/, '')
                        desc = false

                    when /^Depends:\s/ then
                        @pkg.depends = pfl.gsub(/^Depends:\s/, '')
                        desc = true

                    when /^Section:\s/ then
                        @pkg.category = pfl.gsub(/^Section:\s/, '')
                        desc = false
                        
                    when /^Description:\s/ then
                        @pkg.description = pfl.gsub(/^Description:\s/, '')
                        desc = true
                        
                    when /^Priority:\s/ then
                        desc = false
                    when /^Conflicts:\s/ then
                        desc = false
                    when /^Provides:\s/ then
                        desc = false
                    when /^Pre-Depends:\s/ then
                        desc = false
                    when /^Recommends:\s/ then
                        desc = false
                    when /^Suggests:\s/ then
                        desc = false
                    when /^Conffiles:/ then
                        desc = false
                    when /^Architecture:\s/ then
                        desc = false
                    when /^Installed-Size:\s/ then
                        desc = false
                    when /^Enhances:\s/ then
                        desc = false
                    when /^Original-Maintainer:\s/ then
                        desc = false
                    when /^$/ then
                        desc = false
                        
                    else
                        @pkg.description ||= ""
                        @pkg.description += "\n" + pfl if desc
                end
            end
        end
        
        def procPortage(pd)
            $log.debug "Processing Portage package database"
            @fs.chdir(pd)
            
            @fs.dirForeach do |cat|
                next if cat == '.' || cat == '..'
                @fs.chdir(cat)
                
                @fs.dirForeach do |pkg|
                    next if pkg == '.' || pkg == '..'
                    @fs.chdir(pkg)
                    
                    p = pkg
                    v = '???'
                    if pkg =~ /-\d+.*$/
                        p = $`
                        v = $&[1,$&.length]
                    end
                    
                    @pkg = MiqHashStruct.new
                    @pkg.name = p
                    @pkg.version = v
                    @pkg.category = cat
                    @pkg.status = "installed"
                    @pkg.installed = true
                    @fs.fileOpen('DEPEND') { |fo| @pkg.depends = fo.read.chomp } if @fs.fileFile?('DEPEND')
                    @fs.fileOpen('DESCRIPTION') { |fo| @pkg.description = fo.read.chomp } if @fs.fileFile?('DESCRIPTION')
                    @packages << @pkg
                    
                    @fs.chdir('..')
                end
                @fs.chdir('..')
            end
        end
        
        #
        # Client-side RPM DB processing.
        #
        def procRPM(dbDir)
            $log.debug "Processing RPM package database"
            rpmp = MiqRpmPackages.new(@fs, File.join(dbDir, "Packages"))
            rpmp.each { |p| @packages << p }
            rpmp.close
        end
        
        #
        # Conary DB processing
        #
        def procConary(dbFile)
            $log.debug "Processing Conary package database"
            rpmp = MiqConaryPackages.new(@fs, dbFile)
            rpmp.each { |p| @packages << p }
            rpmp.close
        end
        
        def toXml(doc=nil)
            doc = MiqXml.createDoc(nil) if !doc
          
            pkgs = doc.add_element 'applications'
            @packages.each do |p|
                next if !p.installed
                pkgs.add_element('application', {"name" => p.name, "version" => p.version, "description" => p.description, "typename" => p.category, "arch" => p.arch, "release" => p.release})
									# "status" => p.status, "depends" => p.depends
            end
            doc
        end
        
        def toString(doc=nil)
            pkgs = "<applications>\n"
            @packages.each do |p|
                next if !p.installed
                pkgs += "  <application name='#{encodeStrings(p.name)}' version='#{p.version}' description='#{p.description}' typename='#{p.category}' />\n"
            end
            pkgs += "</applications>"
        end
        
        def encodeStrings(data)
            data.gsub!(/>/, "&gt;")
            data.gsub!(/</, "&lt;")
            data.gsub!(/'/, "&apos;")
            data.gsub!(/"/, "&quot;")
            data
        end
        
    end # class Packages
    
end # module MiqLinux

if __FILE__ == $0
    pkgs = MiqLinux::Packages.new
    pkgs.procSsRPM
    xml = pkgs.toXml
    xml.write($stdout, 4)
    puts
end
