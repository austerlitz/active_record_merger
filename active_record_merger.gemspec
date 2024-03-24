# frozen_string_literal: true

require_relative "lib/active_record_merger/version"

Gem::Specification.new do |spec|
  spec.name    = "active_record_merger"
  spec.version = ActiveRecordMerger::VERSION
  spec.authors = ["Max Buslaev"]
  spec.email   = ["max@buslaev.net"]

  spec.summary               = "A utility gem for merging ActiveRecord objects and their associated records with customizable logic."
  spec.description           = "ActiveRecordMerger provides an extendable framework for merging ActiveRecord models, including complex scenarios involving associations, while ensuring data integrity and providing hooks for custom merge logic."
  spec.homepage              = "https://github.com/austerlitz/active_record_merger"
  spec.license               = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yourusername/active_record_merger"
  spec.metadata["changelog_uri"]   = "https://github.com/yourusername/active_record_merger/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]


  spec.add_dependency "activerecord", ">= 5.0"
  spec.add_dependency "simple_command"

  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_development_dependency "pry", "~> 0.13.0"
end
