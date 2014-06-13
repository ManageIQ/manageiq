$:.push("#{File.dirname(__FILE__)}/../../db/MiqBdb")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'binary_struct'
require 'miq-hash_struct'
require 'MiqBdb'
require 'miq-unicode'

# RPM Specification located at: http://jrpm.sourceforge.net/rpmspec/index.html

class MiqRpmPackages
    
    #
    # The data types we support.
    #
    RPM_STRING_TYPE         =  6
    RPM_STRING_ARRAY_TYPE   =  8
    RPM_I18NSTRING_TYPE		=  9
    
    #
    # The things we care about.
    #
    NAME        = 1000
    VERSION     = 1001
    RELEASE     = 1002
    SUMMARY     = 1004
    DESCRIPTION = 1005
    VENDOR      = 1011
    GROUP       = 1016
    ARCH        = 1022
    REQUIRES    = 1049
    
    TAGIDS = {
        1000    => "name",
        1001    => "version",
        1002    => "release",
        1004    => "summary",
        1005    => "description",
        1011    => "vendor",
        1016    => "category",  # group
        1022    => "arch",
        1049    => "depends",   # requires
    }

    #
    # Nubbers on disk are in network byte order.
    #
    RPML_HEADER = BinaryStruct.new([
        'N',        'num_index',
        "N",        'num_data'
    ])
    RPML_HEADER_LEN = RPML_HEADER.size

    ENTRY_INFO = BinaryStruct.new([
        'N',        'tag',
        'N',        'ttype',
        'N',        'offset',
        'N',        'count'
    ])
    ENTRY_INFO_LEN = ENTRY_INFO.size

    def initialize(fs, dbFile)
        @pkgDb = MiqBerkeleyDB::MiqBdb.new(dbFile, fs)
        # Pre-read all pages into the bdb cache, as we will be processing all of them anyway.
        @pkgDb.readAllPages
    end

    def each
        @pkgDb.each_value do |v|
            next if v.length <= RPML_HEADER_LEN
    
            hdr = RPML_HEADER.decode(v)

            offset = RPML_HEADER_LEN + (ENTRY_INFO_LEN * hdr['num_index'])
            if v.length != offset + hdr['num_data']
                $log.debug "record length = #{v.length}"
                $log.debug "num_index = #{hdr['num_index']}"
                $log.debug "num_data = #{hdr['num_data']}"
                $log.error "Invalid or corrupt RPM database record"
                next
            end
            
            data = v[offset, hdr['num_data']]
            pkg = {}

            eis = ENTRY_INFO.decode(v[RPML_HEADER_LEN..-1], hdr['num_index'])
            eis.each do |ei|
                tag = TAGIDS[ei['tag']]
                next if tag.nil?
                pkg[tag] = getVal(data, ei)
            end
            pkg['installed'] = true unless pkg.empty?
            yield(MiqHashStruct.new(pkg))
        end
    end # def each
    
    def close
        @pkgDb.close
    end
    
    private
    
    def getVal(data, ei)
        case ei['ttype']
            when RPM_STRING_TYPE        then return(getStringVal(data, ei['offset']))
            when RPM_STRING_ARRAY_TYPE  then return(getStringArray(data, ei['offset'], ei['count']).join("\n"))
            when RPM_I18NSTRING_TYPE    then return(getStringArray(data, ei['offset'], ei['count']).join("\n").AsciiToUtf8)
            else
                $log.warn "MiqRpmPackages.getVal: unsupported data type: #{ei['ttype']}"
                return("")
        end
    end
    
    def getStringVal(data, offset)
        eos = data.index(0.chr, offset) - offset
        return(data[offset, eos])
    end
    
    def getStringArray(data, offset, count)
        ra = []
        cpos = offset
        
        count.times do
            s = getStringVal(data, cpos)
            ra << s
            cpos += (s.length + 1)
        end
        ra.uniq!
        return(ra)
    end
    
end # class MiqRPM

if __FILE__ == $0
    rpmPkgs = MiqRpmPackages.new(nil, "test/Packages")
    rpmPkgs.each do |pkg|
        puts "Package: #{pkg.name}"
        puts "\tVersion: #{pkg.version}"
        puts "\tRelease: #{pkg.release}"
        puts "\tSummary: #{pkg.summary}"
        puts "\tVendor: #{pkg.vendor}"
        puts "\tArchitecture: #{pkg.arch}"
        puts "\tCategory: #{pkg.category}"
        puts "\tDescription: #{pkg.description}"
        puts "\tDepends: #{pkg.depends}"
    end
end
