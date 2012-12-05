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
large performance gains over ActiveRecord's existing fetch capabilities while
still coercing the results into objects for ease of use.  How much more
performant?  My benchmarks show greater than an order of magnitude increase in
performance when fetching 100,000 rows of data.

```
1.9.3p194 :036 >   prof 'Foo.all' do
1.9.3p194 :037 >       Foo.all
1.9.3p194 :038?>   end
Foo.all: 7492.341262

1.9.3p194 :043 >   prof 'SqlMapper' do
1.9.3p194 :044 >       ActiveRecord::SqlMapper.fetch :query => "select * from foos"
1.9.3p194 :045?>   end
SqlMapper: 474.20788899999997
```

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

You can fetch results using raw inline SQL.  By default, The results will be 
marshalled into structs with attributes matching the column names in your
query.

```ruby
foos = ActiveRecord::SqlMapper.fetch :query => "select * from foos"
```

This is analogous to, but more performant than, using ActiveRecord's all
method.

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

A fetch_one shortcut exists to fetch a single result.  All options and behavior 
apply to both fetch and fetch_one.

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
already familiar with from ActiveRecord.  These can be used in both inline and
named queries.

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
puts foo.to_s
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

## FAQ ##

Q: Am I missing something? Doesn't Arel already do this?
A: Arel is an abstract syntax tree for generating SQL. Sql_mapper is a very simple extension to ActiveRecord that allows you to:
1. Use native sql for the best possible tuned performance in read-only queries.
2. Coerce the data into objects without having to do it yourself.
3. Avoid the performance overhead involved with instantiating full-blown ActiveRecord::Base instances. 

Q: How is this different from doing ActiveRecord::Base.connection.select_all() or whatever?
A: Its not very different, and there is probably no reason to refactor existing
code using that method.  There are, however, reasons to use sql_mapper instead
of that approach if confronted with the issues it is designed to solve:
1. select_all has different results depending on which version of active record you are using (array of arrays or array of hashes).
2. person.name > person[0] for all sorts of reasons.
3. person["name"] is better, but a departure from how you would access data via dot syntax with full blown active record objects. For instance, if you are tasked with "report A takes 10 minutes to generate! FIX IT!" and the code to generate report A is using standard active record objects, it will output each person's name with person.name. You would either have to refactor every place you access data to use the hash syntax, or coerce the data into an object for dot syntax. Sql_mapper does the coercion for you in a really efficient way and its DRY (really DRAAEHDA -- don't repeat anything anyone else has done already).
4. Also, Named queries with sql_mapper allow you to have a logical name for the query that is probably easier to grok at first glance than a really complex query that is 100 lines long and mixed in with your ruby source.
```ruby
ActiveRecord::SqlMapper.fetch :data_for_invoice_report

ActiveRecord::Base.select_all("""
SELECT DATEPART(m, Invoice.InvoiceDate) month, 
       DATEPART(yy, Invoice.InvoiceDate) year, 
       Reseller.Name, 
       SUM(jobstockitems_hardware.Price) sales_hardware,
       SUM(jobstockitems_consumables.Price) sales_consumables, 
FROM Invoice
INNER JOIN Reseller
ON Invoice.CustomerID = Reseller.ID
INNER JOIN Job
ON Invoice.ID = Job.InvoiceID
LEFT JOIN (SELECT JobID, SUM(PriceExTax) Price 
           FROM JobStockItems 
           INNER JOIN Stock 
           ON JobStockItems.StockID = Stock.StockID
           AND Stock.Category1 = 'Hardware'
           GROUP BY JobID) jobstockitems_hardware
ON Job.ID = jobstockitems_hardware.JobID
LEFT JOIN (SELECT JobID, SUM(PriceExTax) Price 
           FROM JobStockItems 
           INNER JOIN Stock 
           ON JobStockItems.StockID = Stock.StockID
           AND Stock.Category1 = 'Consumables'
           GROUP BY JobID) jobstockitems_consumables
ON Job.ID = jobstockitems_consumables.JobID
GROUP BY DATEPART(m, Invoice.Date), 
         DATEPART(yy, Invoice.Date), 
         Reseller.Name
ORDER BY DATEPART(yy, Invoice.Date) ASC, 
         DATEPART(m, Invoice.Date) ASC, 
         Reseller.Name ASC
""")
```
## Contributing ##

Fork it, hack it, test it, then I'll pull it if I like it.
