Gem::Specification.new do |spec|
  spec.name          = 'lita-gitlab2jenkins_ghp'
  spec.version       = '1.0.0'
  spec.authors       = ['Juan Carlos Alonso Holmstron']
  spec.email         = ['j.carlos.alonso.h@gmail.com']
  spec.description   = %q{A Lita Handler for storing gitlabs's pushed events for after send them in a merge request trigger}
  spec.summary       = %q{A Lita Handler for storing gitlabs's pushed events for after send them in a merge request trigger}
  spec.homepage      = 'https://github.com/jcalonsoh/lita-gitlab2jenkins_ghp'
  spec.license       = 'MIT'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'lita', '>= 3.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.0.0.beta2'
  spec.add_development_dependency 'shoulda', '>= 3.5.0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'coveralls'


end
