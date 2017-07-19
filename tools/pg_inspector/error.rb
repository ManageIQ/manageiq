module PgInspector
  module Error
    class PgInspectorError < RuntimeError
    end

    class ApplicationNameIncompleteError < PgInspectorError
    end
  end
end
