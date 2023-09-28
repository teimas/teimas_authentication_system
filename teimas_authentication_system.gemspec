# frozen_string_literal: true

require_relative "lib/teimas_authentication_system/version"

Gem::Specification.new do |spec|
  spec.name = "teimas_authentication_system"
  spec.version = TeimasAuthenticationSystem::VERSION
  spec.authors = ["Teimas Global S.L."]
  spec.email = ["brais.amo@teimas.com"]

  spec.summary = "Keycloak client for authentication and user management"
  spec.description = "This gem strives to ease OID communication, authentication, and user management"
  spec.homepage = "https://github.com/teimas/teimas_authentication_system"
  spec.required_ruby_version = ">= 2.5.0"

  spec.metadata["allowed_push_host"] = "https://github.com/teimas/teimas_authentication_system"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/teimas/teimas_authentication_system"
  spec.metadata["changelog_uri"] = "https://github.com/teimas/teimas_authentication_system"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  spec.add_runtime_dependency "rest-client", "2.1.0"
  spec.add_runtime_dependency "json", "2.6.3"
  spec.add_runtime_dependency "jwt", "2.7.1"
  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
