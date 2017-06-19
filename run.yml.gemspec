# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "run.yml"
  spec.version       = "0.1.2"
  spec.authors       = ["Evgeny Karev\n"]
  spec.email         = ["eskarev@gmail.com"]

  spec.summary       = %q{run.yml}
  spec.description   = %q{run.yml}
  spec.homepage      = "https://github.com/runyml/run-rb"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = "bin"
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_dependency "colorize", "~> 0.8"
  spec.add_dependency "gemoji", "~> 3.0"
end
