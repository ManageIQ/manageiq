require 'binary_struct'
require 'util/miq-hash_struct'
require 'db/MiqSqlite/MiqSqlite3'

class MiqConaryPackages
  def initialize(fs, dbFile)
    @pkgDb = MiqSqlite3DB::MiqSqlite3.new(dbFile, fs)

    tVersions  = @pkgDb.getTable("Versions")
    tInstances = @pkgDb.getTable("Instances")

    @versions = {}
    tVersions.each_row do |row|
      id            = row['versionId']
      @versions[id] = row['version']
    end

    @troves = {}
    tInstances.each_row do |row|
      troveName = row['troveName']
      versionId = row['versionId']
      @troves[troveName] = versionId if @versions.key?(versionId) && !troveName.include?(":") && row['isPresent']
    end
  end

  def each
    @troves.keys.sort.each do |t|
      versionId = @troves[t]
      pkg  = MiqHashStruct.new
      pkg.name      = t
      pkg.version   = @versions[versionId]
      pkg.installed = true

      yield pkg
    end
  end # def each

  def close
    @pkgDb.close
  end
end # class MiqConaryPackages
