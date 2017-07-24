module Api
  class ErrorSerializer
    attr_reader :kind, :error

    def initialize(kind, error)
      @kind = kind
      @error = error
    end

    def serialize
      result = {
        :error => {
          :kind    => kind,
          :message => error.message,
          :klass   => error.class.name
        }
      }
      result[:error][:backtrace] = error.backtrace.join("\n") if Rails.env.test?
      result
    end
  end
end
