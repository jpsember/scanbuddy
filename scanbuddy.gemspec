require 'rake'

Gem::Specification.new do |s|
  s.name        = 'scanbuddy'
  s.version     = '0.1.0'
  s.date        = '2014-10-31'
  s.summary     = "Combine jpegs into pdf"
  s.description = "Processes a directory of jpegs, resampling to a reasonable size, and combining into a single pdf"
  s.authors     = ["Jeff Sember"]
  s.email       = 'jpsember@gmail.com'
  s.files = FileList['lib/**/*.rb',
                      'bin/*',
                      '[A-Z]*',
                      'test/**/*',
                      ]
  s.executables << s.name
  s.add_runtime_dependency 'js_base'
  s.homepage = 'http://www.cs.ubc.ca/~jpsember'
  s.test_files  = Dir.glob('test/*.rb')
  s.license     = 'MIT'
end

