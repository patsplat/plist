# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "plist.newline"
  spec.version       = '3.2.2'
  spec.authors       = ["bkoell"]
  spec.email         = ["bastian.koell@gmail.com"]
  spec.summary       = "plist.newline is an updated version of the plist gem that supports multiline string values"
  spec.description   = "plist.newline is an updated version of the plist gem that supports multiline string values"
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
end
