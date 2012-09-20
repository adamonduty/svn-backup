# -*- encoding: utf-8 -*-
require File.expand_path('../lib/svn-backup/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Adam Lamar"]
  gem.email         = ["adamonduty@gmail.com"]
  gem.description   = %q{svn-backup utilizes the composition properties of subversion dumpfiles and gzip files to efficiently backup large repositories.}
  gem.summary       = %q{An efficient way to backup multiple subversion repositories}
  gem.homepage      = "https://github.com/adamonduty/svn-backup"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "svn-backup"
  gem.require_paths = ["lib"]
  gem.version       = Svn::Backup::VERSION
end
