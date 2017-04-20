# encoding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "plist/version"

Gem::Specification.new do |spec|
  spec.name          = "plist"
  spec.version       = Plist::VERSION
  spec.authors       = ["Ben Bleything", "Patrick May"]

  spec.summary       = "All-purpose Property List manipulation library"
  spec.description   = "Plist is a library to manipulate Property List files, "\
                       "also known as plists. It can parse plist files into "\
                       "native Ruby data structures as well as generating new "\
                       "plist files from your Ruby objects."
  spec.homepage      = "https://github.com/patsplat/plist"
  spec.license       = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.5"
  spec.add_development_dependency "test-unit", "~> 1.2"
end
