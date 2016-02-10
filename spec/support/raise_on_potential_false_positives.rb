module RSpec
  module Matchers
    module BuiltIn
      class RaiseError
        def warn_about_bare_error
          raise %(
            Using the `raise_error` matcher without providing a specific
            error or message risks false positives, since `raise_error`
            will match when Ruby raises a `NoMethodError`, `NameError` or
            `ArgumentError`, potentially allowing the expectation to pass
            without even executing the method you are intending to call.

            Instead, provide a specific error class or message.
          )
        end

        def warn_about_negative_false_positive(expression)
          raise %(
            Using #{expression} risks false positives, since literally
            any other error would cause the expectation to pass,
            including those raised by Ruby (e.g. NoMethodError, NameError
            and ArgumentError), meaning the code you are intending to test
            may not even get reached.

            Instead, use:
            `expect {}.not_to raise_error` or `expect { }.to raise_error(DifferentSpecificErrorClass)`.
          )
        end
      end
    end
  end
end
