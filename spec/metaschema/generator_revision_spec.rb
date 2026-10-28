# frozen_string_literal: true

require "spec_helper"

RSpec.describe Metaschema, ".generator_revision" do
  # Under bundler the gemspec loads version.rb, so a spec process always has it.
  # A consumer that installs the gem does not: loading the library alone must be
  # enough. The child runs without bundler, on this process's load path.
  it "is available after requiring the library alone" do
    lib = File.expand_path("../../lib", __dir__)
    load_path = ([lib] + $LOAD_PATH).uniq.flat_map { |dir| ["-I", dir] }
    unbundled = ENV.keys.grep(/\A(RUBYOPT|RUBYLIB|BUNDLE|BUNDLER)/)
      .to_h { |key| [key, nil] }
    output = IO.popen(
      unbundled,
      [RbConfig.ruby, *load_path, "-e",
       'require "metaschema"; Metaschema.generator_revision; ' \
       "print Metaschema::VERSION"],
      err: %i[child out], &:read
    )

    expect(output).to eq(Metaschema::VERSION)
  end
end
