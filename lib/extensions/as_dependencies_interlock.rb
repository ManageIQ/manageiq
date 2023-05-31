module AsDependenciesInterlock
  # The classic autoloader needs the ActiveSupport::Dependencies.interlock
  # to avoid deadlocks.  With zeitwerk, this actually causes deadlocks so
  # we only use the interlock with the classic autoloader.
  def loading(&block)
    if Rails.application.config.autoloader == :zeitwerk
      warn_about_zeitwerk_and_interlock
      yield
    else
      super
    end
  end

  def permit_concurrent_loads(&block)
    if Rails.application.config.autoloader == :zeitwerk
      warn_about_zeitwerk_and_interlock
      yield
    else
      super
    end
  end

  def warn_about_zeitwerk_and_interlock
    @warn_about_zeitwerk_and_interlock ||= begin
      warn ":zeitwerk is the configured autoloader. This patched file should be removed: #{__FILE__} once support for the classic loader is dropped. Additionally remove all uses of AS::Depedencies.interlock."
      true
    end
  end
end

ActiveSupport::Dependencies.interlock.singleton_class.prepend(AsDependenciesInterlock)
