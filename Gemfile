source "https://rubygems.org"
gemspec

if Gem::Requirement.new("< 2.2").satisfied_by?(Gem::Version.new(RUBY_VERSION))
  gem "rake", "~> 11.3"
else
  gem "rake", "~> 13.0"
end

if Gem::Requirement.new(">= 3.3").satisfied_by?(Gem::Version.new(RUBY_VERSION))
  gem "base64"
end

gem "test-unit", "~> 3.5"
