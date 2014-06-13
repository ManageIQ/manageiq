require 'pathname'

module Build
  class Productization
    BUILD_DIR = Pathname.new(File.dirname(__FILE__)).freeze
    PROD_DIR  = BUILD_DIR.join('productization').freeze

    def self.file_for(path)
      prod_file  = PROD_DIR.join(path)
      build_file = BUILD_DIR.join(path)
      File.exists?(prod_file) ? prod_file : build_file
    end
  end
end
