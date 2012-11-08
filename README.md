sql_mapper
==========

An extension for ActiveRecord to improve read performance for large data sets 
at the sacrifice of some AR magic.

The basic use case for SQL Mapper is:

1. You need read only data
2. Your data is flat and can be contained within a single query.
3. Normal use of ActiveRecord is not performant enough

If all of the above is true, sql_mapper can help leverage raw_sql to provide
an order of magnitude performance improvement over ActiveRecord's existing
fetch capabilities while still coercing the results into objects for ease of
use after fetching.

Why is ActiveRecord slow in these cases?  Read more here 
http://merbist.com/2012/02/23/quick-dive-into-ruby-orm-object-initialization/

See examples of sql_mapper use at https://gist.github.com/4000974
