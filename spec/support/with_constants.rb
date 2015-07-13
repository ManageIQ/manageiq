#
# Allows temporarily overriding constants for a particular test.
# Gleaned from http://digitaldumptruck.jotabout.com/?p=551
#
# Example:
#   it "does not allow links to be added in production environment" do
#     Object.with_constants :RAILS_ENV => 'production' do
#       get :add, @nonexistent_link.url
#       response.should_not be_success
#     end
#   end
#
class Module
  def with_constants(constants, &block)
    saved_constants = {}
    constants.each do |constant, val|
      saved_constants[ constant ] = const_get( constant )
      Kernel::silence_warnings { const_set( constant, val ) }
    end

    begin
      block.call
    ensure
      constants.each do |constant, val|
        Kernel::silence_warnings { const_set( constant, saved_constants[ constant ] ) }
      end
    end
  end
end
