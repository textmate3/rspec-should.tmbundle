require 'json'
require 'prism'
require 'strscan'

# The snippets are property lists, read with macOS's own plutil,
# which is on every Mac TextMate runs on.
module SnippetFiles
  BUNDLE = File.expand_path('../..', __dir__)

  def self.all
    Dir[File.join(BUNDLE, 'Snippets', '*.tmSnippet')].sort.map do |path|
      json = IO.popen(['plutil', '-convert', 'json', '-o', '-', path], &:read)
      raise "#{path} is not a property list" unless $?.success?

      JSON.parse(json).merge('file' => File.basename(path))
    end
  end

  def self.inserting(pattern)
    all.select { |snippet| snippet['content'] =~ pattern }.map { |snippet| snippet['file'] }
  end
end

# What a snippet inserts when every tab stop keeps its default:
# a placeholder becomes its default, a choice its first option,
# a mirror the value of the tab stop it mirrors,
# a transformation or variable a stand in name,
# and an empty tab stop the filler, nothing or what a person would type.
class SnippetExpansion
  def initialize(content, filler:)
    @scanner = StringScanner.new(content)
    @filler  = filler
    @values  = {}
  end

  def to_s = expand(until_brace: false)

  # The words of every placeholder's default, which stand in for a person's own names.
  def placeholder_words
    to_s
    @values.values.join(' ').scan(/\w+[?!]?/)
  end

  private

  def expand(until_brace:)
    out = +''
    until @scanner.eos?
      if until_brace && @scanner.check(/\}/)
        @scanner.skip(/\}/)
        return out
      elsif @scanner.scan(/\\(.)/m)
        out << @scanner[1]
      elsif @scanner.scan(/\$\{(\w+)\|/)
        name = @scanner[1]
        out << (@values[name] = @scanner.scan(/[^,|]*/))
        @scanner.skip(/[^|]*\|\}/)
      elsif @scanner.scan(/\$\{(\w+):-?/)
        name = @scanner[1]
        out << (@values[name] = expand(until_brace: true))
      elsif @scanner.scan(/\$\{\w+\/(?:\\.|[^\\\/])*\/(?:\\.|[^\\\/])*\/\w*\}/)
        out << 'Subject'
      elsif @scanner.scan(/\$\{(\d+)\}|\$(\d+)/)
        out << @values.fetch(@scanner[1] || @scanner[2], @filler)
      elsif @scanner.scan(/\$\{([A-Z_]+)\}|\$([A-Z_]+)/)
        out << 'Subject'
      else
        out << @scanner.getch
      end
    end
    out
  end
end

RSpec.describe 'The snippets' do
  it 'are each a property list with content, a name, a scope, a tab trigger and a uuid' do
    incomplete = SnippetFiles.all.reject do |snippet|
      %w[content name scope tabTrigger uuid].all? { |key| snippet.key?(key) }
    end

    expect(incomplete).to eq([])
  end

  it 'only work in spec files of projects that turn the should syntax on' do
    scopes = SnippetFiles.all.map { |snippet| snippet['scope'] }.uniq

    expect(scopes).to eq(['source.ruby.rspec attr.rspec.should'])
  end

  it 'insert Ruby that parses, with every tab stop at its default' do
    # An empty tab stop is either left empty, as in .should_not $0,
    # or where a person has to type something, as in .stub(:message)$3.
    unparsed = SnippetFiles.all.reject do |snippet|
      ['', 'filled_in'].any? do |filler|
        ruby = SnippetExpansion.new(snippet['content'], filler:).to_s
        Prism.parse(ruby).success?
      end
    end

    expect(unparsed.map { |snippet| snippet['file'] }).to eq([])
  end

  it 'insert only names an RSpec example or example group defines, with the should syntax on' do
    # Loading rspec-rails takes a Rails application,
    # so its names were checked against the rspec-rails 8.0.4 source instead.
    # be_redirect is a predicate matcher on the response's redirect? method.
    rspec_rails = %w[be_redirect have_http_status redirect_to render_template response]

    undefined = SnippetFiles.all.flat_map do |snippet|
      expansion = SnippetExpansion.new(snippet['content'], filler: '')
      calls = []
      queue = [Prism.parse(expansion.to_s).value]
      until queue.empty?
        node = queue.shift
        calls << node.name.to_s if node.is_a?(Prism::CallNode) && node.receiver.nil?
        queue.concat(node.compact_child_nodes)
      end

      calls.reject do |name|
        expansion.placeholder_words.include?(name) ||
          rspec_rails.include?(name) ||
          # Asking respond_to? would let any be_ or have_ name through,
          # since RSpec turns those into predicate matchers at run time.
          self.class.method_defined?(name) ||
          self.class.private_method_defined?(name) ||
          self.class.respond_to?(name) ||
          # Modifiers, like and_return or once, chain onto a message expectation.
          RSpec::Mocks::MessageExpectation.method_defined?(name)
      end.map { |name| "#{snippet['file']}: #{name}" }
    end

    expect(undefined).to eq([])
  end

  it 'never give a negative raise_error an error class, which RSpec 3 rejects' do
    expect(SnippetFiles.inserting(/should_not raise_error\(/)).to eq([])
  end
end
