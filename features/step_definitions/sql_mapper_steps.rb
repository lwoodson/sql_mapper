require 'rubygems'
require 'rspec/expectations'
require 'active_record'
require 'ostruct'
load './lib/sql_mapper.rb'

class Foo
  attr_reader :id, :name

  def initialize(id, name)
    @id = id
    @name = name
  end
end

Before do
  ActiveRecord::SqlMapper.config do
    map :all_foos, "select * from foos order by id"
    map :a_foo, "select * from foos where id = ?"
    map :all_foos_as_foos, "select * from foos order by id", Foo
    map :a_foo_as_foo, "select * from foos where id = ?", Foo
  end
end

Given /a connection to sqlite database/ do 
  ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'
  @conn = ActiveRecord::Base.connection
end

Given /a connection to a postgres database/ do
  ActiveRecord::Base.establish_connection :adapter => 'postgresql', 
                                          :database => 'sql_mapper_test', 
                                          :username => 'postgres'
  @conn = ActiveRecord::Base.connection
end

Given /a connection to a mysql database/ do
  ActiveRecord::Base.establish_connection :adapter => 'mysql',
                                          :database => 'sql_mapper_test',
                                          :username => 'root'
  @conn = ActiveRecord::Base.connection
end

Given /a table named foos with (\d+) records/ do |count|
  @conn.execute "drop table foos" rescue nil
  @conn.execute "create table foos (id bigint, name varchar(100))"
  (0..count.to_i-1).each do |i|
    @conn.execute "insert into foos values (#{i}, 'foo_#{i}')"
  end
end

When /I fetch foos using inline sql and (\w+) result_class/ do |result_class|
  @results = ActiveRecord::SqlMapper.fetch :query => 'select * from foos order by id',
                                           :result_class => result_class.constantize
end

When /^I fetch foos using inline sql$/ do
  @results = ActiveRecord::SqlMapper.fetch :query => 'select * from foos order by id'
end

When /I fetch foos using a query named (\w+) and (\w+) result_class/ do |query_name, result_class|
  @results = ActiveRecord::SqlMapper.fetch :query => query_name.to_sym,
                                           :result_class => result_class.constantize
end

When /^I fetch foos using a query named (\w+)$/ do |query_name|
  @results = ActiveRecord::SqlMapper.fetch :query => query_name.to_sym
end

Then /my results should have (\d+) foos each coerced into a (\w+)/ do |count, type|
  @results.size.should == count.to_i
  (0..count.to_i-1).each do |i|
    check_result(@results[i], type, i)
  end
end

When /^I fetch_one foo with id (\d+) using inline sql$/ do |id|
  @results = ActiveRecord::SqlMapper.fetch_one :query => "select * from foos where id = ?", :params => id.to_i
end

When /^I fetch_one foo with id (\d+) using a query named (\w+)$/ do |id, query_name|
  @results = ActiveRecord::SqlMapper.fetch_one :query => query_name.to_sym, :params => id.to_i
end

When /^I fetch_one foo with id (\d+) using inline sql and (\w+) result_class$/ do |id, result_class|
  @results = ActiveRecord::SqlMapper.fetch_one :query => "select * from foos where id = ?", 
                                               :params => id.to_i, 
                                               :result_class => result_class.constantize
end

When /^I fetch_one foo with id (\d+) using a query named (\w+) and (\w+) result_class$/ do |id, query_name, result_class|
  @results = ActiveRecord::SqlMapper.fetch_one :query => query_name.to_sym, 
                                               :params => id.to_i, 
                                               :result_class => result_class.constantize
end

Then /my result should be a foo with id (\d+) coerced into a (\w+)/ do |id, type|
  check_result(@results, type, id)
end

def check_result(result, type, id)
  result.kind_of?(type.constantize).should == true
  if result.kind_of? Hash
    result[:id].to_i.should == id.to_i
    result[:name].should == "foo_#{id}"
  else
    result.id.to_i.should == id.to_i
    result.name.should == "foo_#{id}"
  end
end
