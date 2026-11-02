# RSpec Should TextMate Bundle

Snippets for RSpec's `should` syntax: `actual.should eq(expected)`, `object.should_receive(:message)`, `double.stub(:message)` and the rest.

RSpec 3 made `should` an opt-in, and the [RSpec bundle](https://github.com/rspec/rspec.tmbundle) writes the `expect` syntax. This bundle is for projects that still turn `should` on:

```ruby
RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
  config.mock_with(:rspec) { |c| c.syntax = :should }
end
```

## Installation

Install it from TextMate's bundle preferences. It requires the RSpec bundle, which installs with it.

## Turning it on in a project

The snippets only work in projects that say they use `should`. Add this line to a `.tm_properties` file at the root of the project:

```text
scopeAttributes = attr.rspec.should
```

If the project already sets `scopeAttributes`, add the name to the same setting, separated by a space and quoted:

```text
scopeAttributes = "attr.other attr.rspec.should"
```

Everywhere else, the RSpec bundle's `expect` snippets are all there is.

## License

The snippets come from the RSpec bundle, and the license is the same as RSpec's, MIT. See [License.txt](License.txt).
