Gem::Specification.new do |s|
  s.name = 'sql_mapper'
  s.version = '0.0.1'
  s.date = '2012-11-01'
  s.summary = """
  ActiveRecord extension that provides large performance improvements
  when you need large sets of read-only data and do not need the
  magic of ActiveRecord.
  """
  s.description = s.summary
  s.authors = ["Lance Woodson"]
  s.email = 'lance@webmaneuvers.com'
  s.files = ["lib/sql_mapper.rb"]
  s.homepage = 'https://github.com/lwoodson/sql_mapper'

  s.add_runtime_dependency "activerecord", ">= 2.3.0"

  s.add_development_dependency 'mysql', '>= 2.8.1'
  s.add_development_dependency 'pg', '>= 0.11.0'
  s.add_development_dependency 'sqlite3', '>= 1.3.4'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'cucumber'
  s.add_development_dependency 'ruby-debug'
end
