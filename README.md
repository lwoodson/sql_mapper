# sql_mapper #

An extension for ActiveRecord to improve read performance for large data sets 
at the sacrifice of some AR magic.

The basic use case for SQL Mapper is:

1. You need read only data
2. Your data is flat and can be contained within a single query.
3. Normal use of ActiveRecord is not performant enough
4. You are not dependent upon ActiveRecord magic to do the job after you have
the data.

If all of the above is true, sql_mapper can help leverage raw sql to provide
an order of magnitude performance improvement over ActiveRecord's existing
fetch capabilities while still coercing the results into objects for ease of
use after fetching.

Why is ActiveRecord slow in these cases?  Read more here 
http://merbist.com/2012/02/23/quick-dive-into-ruby-orm-object-initialization/

Why raw sql?  Its a data fetching DSL.

## Examples ##

All of the examples assume we have a table named <tt>Foos</tt> defined as
follows:

```sql
create table Foos (
  id serial,
  name string
);
```

### Inline SQL ###

You can fetch results using raw inline SQL.  The results will be marshalled
into structs with attributes matching the column names in your query by
default.

```ruby
foos = ActiveRecord::SqlMapper.fetch :query => "select * from foos"
```

The above has a 10x performance increase over standard ActiveRecord querying:

```ruby
foos = Foo.all
```

### Accessing Column Values ###

As the result objects are structs, you can access column data through the object 
using column names and dot notation.

```ruby
foos = ActiveRecord::SqlMapper.fetch :query => "select * from foos"
foos.each do |foo|
  puts "#{foo.id}: #{foo.name}"
end
```

### Single Result Shortcut ###

A fetch_one shortcut exists to fetch a single result.  All of the other options
and behavior apply to both fetch and fetch_one.

```ruby
foo = ActiveRecord::SqlMapper.fetch_one :query => "select * from foos limit 1"
```

### Named Queries ###

SQL queries can be mapped to logical names within a configuration block,
allowing you to pass the logical name to the fetch method and keeping the sql
compartmentalized within your app.  In a rails application, this configuration
should be put in an initializer.

```ruby
ActiveRecord::SqlMapper.config do
  map :all_foos, "select * from foos"
end

foos = ActiveRecord::SqlMapper.fetch :query => :all_foos
```

### Parameters ###

SQL queries can contain parameters using ? or :name placeholders that you are
already familiar with from ActiveRecord.  These can be used in named queries.

```ruby
sql = "select * from foos where id = ?"
foo = ActiveRecord::SqlMapper.fetch_one :query => sql, :params => 1
foo = ActiveRecord::SqlMapper.fetch_one :query => sql, :params => [1]

sql = "select * from foos where id = :id"
foo = ActiveRecord::SqlMapper.fetch_one :query => sql, :params => {:id => 1}
```

### Result Classes ###

By default, sql mapper results are structs, but you can also use hashes by
specifying the result class to fetch or fetch_one.  

```ruby
sql = "select * from foos where id = ?"
foo = ActiveRecord::SqlMapper.fetch :query => sql,
                                     :params => 1,
                                     :result_class => Hash
puts foo[:id]
puts foo[:name]
```

You can also use any arbitrary class for results as long as it has an
initializer that contains arguments for all columns in the same order.  This
can be useful if you want behavior attached to your results.

```ruby
class Foo
  attr_reader :id, :name

  def initialize(id, name)
    @id = id
    @name = name
  end

  def to_s
    "Foo(#{id}, #{name})"
  end
end

sql = "select * from foos where id = ?"
foo = ActiveRecord::SqlMapper.fetch_one :query => sql,
                                        :params => 1,
                                        :result_class => Foo
puts foo
```

Result classes can also be specified in the configuration at either a global
or per-query level.

```ruby
ActiveRecord::SqlMapper.config do
  result_class Hash
  map :all_foos, "select * from foos", Foo
end
```

## More Examples ##

See examples of sql_mapper use at https://gist.github.com/4000974

## Versions ##
Tests have been run and verified with ActiveRecord 3.2, 2.3.8, 2.3.5.  Let me
know if you have any problems with the gem using active record > 2.3.5.

## Contributing ##

Fork it, hack it, test it, then I'll pull it if I like it.
