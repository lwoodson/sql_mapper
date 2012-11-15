require 'singleton'
require 'active_record'

module ActiveRecord
  module SqlMapper
    def self.config(&block)
      Context.instance.instance_exec &block
    end

    def self.fetch(opts={})
      strategy = get_strategy_for(*sql_and_result_class_for(opts))
      strategy.do_fetch
      strategy.process_results
    end

    def self.fetch_one(opts={})
      fetch(opts)[0]
    end

    class Context
      include Singleton
      
      def initialize
        @default_result_class = Struct
        @queries = {}
      end

      def queries
        @queries.dup
      end

      def named_query_exists?(sym)
        @queries.include? sym
      end

      def map(name, sql, result_class=nil)
        mapping = QueryMapping.new name, sql, result_class
        @queries[name] = mapping
      end

      def result_class(clazz=nil)
        @default_result_class = clazz if not clazz.nil? and clazz.is_a? Class
        @default_result_class
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

    class ObjectExecStrategy
      def initialize(sql, result_class)
        @sql = sql
        @result_class = result_class
      end

      def do_fetch
        @raw_results = ActiveRecord::Base.connection.exec_query(@sql)
      end

      def process_results
        @raw_results.rows.map &instantiate_result_using_row
      end

      private
      def instantiate_result_using_row
        lambda {|row| @result_class.new *row}
      end
    end

    class StructExecStrategy < ObjectExecStrategy
      def initialize(sql, result_class)
        super(sql, result_class)
      end

      def do_fetch
        @raw_results = ActiveRecord::Base.connection.exec_query(@sql)
        @result_class = create_struct_instance_from_col_names(@raw_results)
      end

      private
      def create_struct_instance_from_col_names(raw_results)
        Struct.new *extract_col_names_from(raw_results)
      end

      def extract_col_names_from(raw_results)
        raw_results.columns.map{|c| c.to_sym}
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
      :object => ObjectExecStrategy,
      Struct => StructExecStrategy,
      Hash => HashExecStrategy
    }

    private
    def self.sql_and_result_class_for(opts={})
      raise ":query option must be specified" if not opts.include? :query
      sql, result_class = obtain_sql_and_result_class_for(opts[:query], opts[:result_class])
      sql = inject_params_into(sql, opts[:params])
      [sql, result_class]
    end

    def self.wrap_non_arrays_in_array(val)
      if val.kind_of? Array
        val
      else
        [val]
      end
    end

    def self.get_strategy_for(sql, result_class)
      get_strategy_class_for(result_class).new(sql, result_class)
    end

    def self.get_strategy_class_for(result_class)
      (EXEC_STRATEGIES[result_class] || EXEC_STRATEGIES[:object])
    end

    def self.obtain_sql_and_result_class_for(query, result_class)
      if is_named_query(query)
        mapping = Context.instance.queries[query]
        sql = mapping.sql
        result_class = result_class || mapping.result_class || Context.instance.result_class
      else
        sql = query
        result_class = result_class || Context.instance.result_class
      end
      [sql, result_class]
    end

    def self.is_named_query(query)
      result = false
      if query.kind_of? Symbol
        if Context.instance.named_query_exists?(query)
          result = true
        else
          raise "No query named #{query} found"
        end
      end
      result
    end

    def self.inject_params_into(sql, params)
      unless params.nil?
        sql_array = [sql] + wrap_non_arrays_in_array(params)
        sql = ActiveRecord::Base.send :sanitize_sql_array, sql_array
      end
      sql
    end
  end
end
