$:.push("#{File.dirname(__FILE__)}/../../db/MiqSqlite")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'binary_struct'
require 'miq-hash_struct'
require 'MiqSqlite3'

class MiqConaryPackages
    def initialize(fs, dbFile)
      @pkgDb = MiqSqlite3DB::MiqSqlite3.new(dbFile, fs)
      
      tVersions  = @pkgDb.getTable("Versions")
      tInstances = @pkgDb.getTable("Instances")

      @versions = Hash.new
      tVersions.each_row { |row|
        id            = row['versionId']
        @versions[id] = row['version']
      }
      
      @troves = Hash.new
      tInstances.each_row { |row|
        troveName = row['troveName']
        versionId = row['versionId']
        @troves[troveName] = versionId if @versions.has_key?(versionId) && !troveName.include?(":") && row['isPresent']
      }

    end

    def each
      @troves.keys.sort.each { |t|
        versionId = @troves[t]
        pkg  = MiqHashStruct.new
        pkg.name      = t
        pkg.version   = @versions[versionId]
        pkg.installed = true

        yield pkg
      }
    end # def each
    
    def close
      @pkgDb.close
    end
    
end # class MiqConaryPackages
