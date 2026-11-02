RSpec.configure do |config|
  # The snippets insert the should syntax,
  # so the spec that checks their names against RSpec turns it on, beside expect.
  config.expect_with(:rspec) { |expectations| expectations.syntax = %i[should expect] }
  config.mock_with(:rspec) { |mocks| mocks.syntax = %i[should expect] }

  config.order = :random
end

# A failure lists every snippet it found, not the first few.
RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = nil
