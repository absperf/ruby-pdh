require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'win32-pdh'
  spec.version    = '0.1.1'
  spec.authors    = ['Taylor C. Richberger']
  spec.license    = 'MIT'
  spec.email      = 'tcr@absolute-performance.com'
  spec.homepage   = 'http://github.com/absperf/win32-pdh'
  spec.summary    = 'Interface for the MS Windows PDH counters'
  spec.description = 'Ruby FFI interface for Windows PDH'
  spec.files      = [
    'lib/win32/pdh.rb',
    'lib/win32/pdh/query.rb',
    'lib/win32/pdh/counter.rb',
    'lib/win32/pdh/constants.rb',
  ]

  spec.add_dependency('ffi')
end
