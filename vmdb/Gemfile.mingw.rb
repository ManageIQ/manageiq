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
      devkit = File.expand_path(File.join("/", %w{pik devkit devkitvars.bat})).gsub('/', '\\') unless File.exist?(devkit)
      devkit = File.expand_path(File.join("C:", %w{pik devkit devkitvars.bat})).gsub('/', '\\') unless File.exist?(devkit)
      puts "  Your devkitvars.bat file is located here: #{devkit}" if File.exist?(devkit)

      exit 1
    end
  end

  def self.check_all
    check_postgres
  end

  def self.prepare_all
    prepare_postgres
  end

  def self.cleanup_all
    # Cleanup in reverse order.
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
    if File.exist?("X:")
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
end

# All that for this...
WindowsBundler.prepare
