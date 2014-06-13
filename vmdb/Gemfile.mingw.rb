begin
  # Enable colored console so bundler's output isn't cluttered with ANSI codes
  require 'win32console' 
rescue LoadError
end

module WindowsBundler
  # Setup any build artifacts during bundler install or update, and allow it to
  #   only be run once, since the Gemfile may be loaded more than once.
  def self.prepare
    return if @prepared
    return unless ["install", "update"].include?(ARGV.first)
    @prepared = true

    # Check for the DevKit until the next version of bundler is released (~1.1),
    #   which may do it automatically.
    check_devkit

    check_all

    at_exit do
      puts "Cleaning up Windows specific build artifacts"
      cleanup_all
    end

    puts "Setting up Windows specific build artifacts"
    prepare_all
  end

  def self.check_devkit
    if ENV["RI_DEVKIT"].nil?
      puts "The DevKit environment variables have not been set."
      puts "  Manually run the devkitvars.bat from the devkit directory first."

      devkit = File.expand_path(File.join(Gem.bindir, %w{.. .. devkit devkitvars.bat})).gsub('/', '\\')
      devkit = File.expand_path(File.join("/", %w{pik devkit devkitvars.bat})).gsub('/', '\\') unless File.exists?(devkit)
      devkit = File.expand_path(File.join("C:", %w{pik devkit devkitvars.bat})).gsub('/', '\\') unless File.exists?(devkit)
      puts "  Your devkitvars.bat file is located here: #{devkit}" if File.exists?(devkit)

      exit 1
    end
  end

  def self.check_all
    check_postgres
    # check_rmagick
  end

  def self.prepare_all
    prepare_postgres
    # prepare_rmagick
  end

  def self.cleanup_all
    # Cleanup in reverse order.
    # begin; cleanup_rmagick;  rescue Exception; end
    begin; cleanup_postgres; rescue Exception; end
  end

  #
  # Utility methods for check/prepare/cleanup methods
  #
  def self.which(executable)
    which = `where #{executable}`.split("\n").first
    (which.nil? || which.empty? || which[0, 5] == "INFO:") ? "" : which
  end

  #
  # PostgreSQL
  #

  def self.check_postgres
    if File.exists?("X:")
      puts "ERROR: X: drive is already mapped, please unmap it."
      exit 1
    end

    if which("postgres").empty?
      puts "ERROR: PostgreSQL is not installed or is not in the PATH."
      exit 1
    end
  end

  def self.prepare_postgres
    `subst X: "#{File.dirname(which("postgres")).chomp("\\bin")}"`
    `bundle config build.postgres --with-pgsql-dir=X: --with-/ms/libpqlib=pq`
  end

  def self.cleanup_postgres
    `subst /D X:`
  end

  #
  # RMagick
  #

  def self.check_rmagick
    if File.exists?("Y:")
      puts "ERROR: Y: drive is already mapped, please unmap it."
      exit 1
    end

    rm_dir = which("imdisplay")
    if rm_dir.empty?
      puts "ERROR: ImageMagick is not installed or is not in the PATH."
      puts
      puts "You can get the installer here:"
      puts "  http://www.imagemagick.org/script/binary-releases.php#windows"
      puts "Be sure to install the version that matches your Ruby architecture."
      exit 1
    end
    rm_dir = File.dirname(rm_dir)

    # Check for the issue where Windows has a system command called convert, which
    #   clashes during one of the internal rmagick checks.
    unless which("convert").include?(rm_dir)
      puts "ERROR: ImageMagick is in the PATH, but must be ahead of the system"
      puts "  directories so that the rmagick gem can be installed."
      puts
      puts "Run the following command line to set the PATH properly:"
      puts "  set PATH=#{rm_dir};%PATH%"
      exit 1
    end
  end

  def self.prepare_rmagick
    `subst Y: "#{File.dirname(which("imdisplay"))}"`
    `bundle config build.rmagick --with-opt-dir=Y:`
  end

  def self.cleanup_rmagick
    `subst /D Y:`
  end
end

# All that for this...
WindowsBundler.prepare