require 'singleton'
require 'active_record'

module ActiveRecord
  module SqlMapper
    class Context
      include Singleton
      
      def initialize
        @result_class = Struct
        @queries = {}
      end

      def queries
        @queries.dup
      end

      def map(name, sql, result_class=nil)
        mapping = QueryMapping.new name, sql, result_class
        @queries[name] = mapping
      end

      def result_class(clazz=nil)
        @result_class = clazz if not clazz.nil? and clazz.is_a? Class
        @result_class
      end
    end

    class QueryMapping
      attr_reader :key
      attr_accessor :sql, :result_class

      def initialize(key, sql, result_class=nil)
        @key = key
        @sql = sql
        @result_class = result_class
      end
    end

    class DefaultExecStrategy
      def initialize(sql, result_class)
        @sql = sql
        @result_class = result_class
      end

      def do_fetch
        @raw_results = ActiveRecord::Base.connection.exec_query(@sql)
      end

      def process_results
        @raw_results.rows.map{|row| @result_class.new *row}
      end
    end

    class StructExecStrategy < DefaultExecStrategy
      def initialize(sql, result_class)
        super(sql, result_class)
      end

      def do_fetch
        @raw_results = ActiveRecord::Base.connection.exec_query(@sql)
        col_names = @raw_results.columns.map{|c| c.to_sym}
        @result_class = @result_class.new(*col_names)
      end
    end

    class HashExecStrategy
      def initialize(sql, result_class)
        @sql = sql
        @result_class = result_class
      end

      def do_fetch
        @raw_results = ActiveRecord::Base.connection.select_all(@sql)
      end

      def process_results
        @raw_results.map{|hash| symbolize_hash hash}
      end

      private
      def symbolize_hash(hash)
        hash.inject({}) {|new,(k,v)| new[k.to_sym] = v; new}
      end
    end

    # Json execution strategy?
    EXEC_STRATEGIES = {
      :default => DefaultExecStrategy,
      Struct => StructExecStrategy,
      Hash => HashExecStrategy
    }

    def self.config(&block)
      Context.instance.instance_exec &block
    end

    def self.fetch(opts={})
      sql, result_class = construct_sql_for opts
      strategy_class = (EXEC_STRATEGIES[result_class] || EXEC_STRATEGIES[:default])
      strategy = strategy_class.new(sql, result_class)
      strategy.do_fetch
      strategy.process_results
    end

    def self.fetch_one(opts={})
      results = fetch(opts)
      results[0]
    end

    private
    def self.construct_sql_for(opts={})
      raise ":query option must be specified" if not opts.include? :query
      sql = opts[:query]

      result_class = opts[:result_class] || Context.instance.result_class
      if opts[:query].kind_of? Symbol
        mapping = Context.instance.queries[opts[:query]]
        raise "No query named #{opts[:query]} found" if mapping.nil?
        sql = mapping.sql
        result_class = mapping.result_class || result_class
      end

      if opts.include? :params
        sql_array = [sql] + wrap_non_arrays_in_array(opts[:params])
        sql = ActiveRecord::Base.send :sanitize_sql_array, sql_array
      end
      [sql, result_class]
    end

    def self.wrap_non_arrays_in_array(val)
      if val.kind_of? Array
        val
      else
        [val]
      end
    end
  end
end
