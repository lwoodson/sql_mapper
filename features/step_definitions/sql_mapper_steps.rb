require 'rubygems'
require 'rspec/expectations'
require 'active_record'
require 'ostruct'
load './lib/sql_mapper.rb'

Before do
  ActiveRecord::SqlMapper.config do
    map :all_foos, "select * from foos order by id"
    map :a_foo, "select * from foos where id = ?"
  end
end

Given /a connection to (\w+) database (.+)$/ do |adapter, db|
  ActiveRecord::Base.establish_connection :adapter => adapter, :database => db
  @conn = ActiveRecord::Base.connection
end

Given /a table named foos with (\d+) records/ do |count|
  @conn.execute "create table foos (id serial, name string)"
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

When /I fetch_one foo with id (\d+) using inline sql/ do |id|
  @results = ActiveRecord::SqlMapper.fetch_one :query => "select * from foos where id = ?", :params => id.to_i
end

When /I fetch_one foo with id (\d+) using a query named (\w+)/ do |id, query_name|
  @results = ActiveRecord::SqlMapper.fetch_one :query => query_name.to_sym, :params => id.to_i
end

Then /my result should be a foo with id (\d+) coerced into a (\w+)/ do |id, type|
  check_result(@results, type, id)
end

def check_result(result, type, id)
  result.kind_of?(type.constantize).should == true
  if result.kind_of? Hash
    result[:id].should == id.to_i
    result[:name].should == "foo_#{id}"
  else
    result.id.should == id.to_i
    result.name.should == "foo_#{id}"
  end
end
