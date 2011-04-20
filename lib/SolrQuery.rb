module SolrQuery
    
  class AbstractQuery
    
    # We're building up a naive parse tree of sorts: 
    # op is AND/OR/NOT, left and right are children

    attr_accessor :op, :left, :right
    
    # Initialize the query object.
    # This will need to be overridden by anything that
    # doesn't take a single field/boost (e.g., DisMax)
    #
    # @param [String] tokens The query string
    # @param [String] field The field to search on
    # @param [Float] boost The boost for this whole query
    # @return [AbstractQuery or subclass] The new query object.
    
    
    def initialize tokens=nil, field=nil, boost=nil
      @tokens = tokens
      @field = field
      @boost = boost
      @type = "lucene"
      @lp = {}
    end
    
    # Take a hash that maps termstring to URL arguments and return 
    # a string that will go in the URL (not yet URL-encoded) based on it
    # for this query type. The reason to use the termhash is so you can have
    # multiple queries all using the same terms,e.g.
    # http://...?q=_query_:"{!lucene df='author1' v=$q1}" OR _query_:"{!lucene df='author2' v=$q1}"&q1=my search terms
    #
    # This default method takes care of anything in the @lp (localParams) and a basic boost
    #
    # Everything in the termhash gets turned into URL components, so if you need to stick extra
    # stuff in there, you can (for, e.g., boost queries)
    #
    # @param [Hash] termhash A hash mapping search strings to q1/q2/etc. Generally the output of
    # self.terms

    def leafnode termhash
      b = @boost? '^' + @boost.to_s : ''
      id = termhash[@tokens]
    
      args = @lp.each.map{|k,v| "#{k}='#{v}'"}.join(' ')
      
      args = ' ' + args if args != ''
      return "_query_:\"{!#{@type}#{args} v=$#{id}}\"#{b}"
    end
    
    
    # In inner == false, return a hash of all the term strings mapped to arbitrary
    # identifiers (in this implementation, q1, q2, ...). 
    #
    # If inner == true, return an Array of term strings, which will (later on) be 
    # deduplicated and turned into the hash.
    #
    # Basically, call it with inner==false on the node you want to 
    # get the termlist for.
    
    def terms inner = nil
      t = []
      if @op
        if @left
          t += @left.terms(true) + @right.terms(true)
        else
          t += @right.terms(true)
        end
      else 
        t = self.leafterms
      end
      
      if inner
        return t
      else
        t = t.compact.uniq
        rv = {}
        t.each_with_index do |v, i|
          rv[v] = "q#{i}"
        end
        return rv
      end
    end
    
  
    def conjoin op, other
      nq = self.class.new
      nq.op = op
      if other
        nq.left = self
        nq.right = other
      else
        nq.right = self
      end
      return nq
    end    
    
    def -@
      return self.conjoin 'NOT', nil
    end
    
    def * other
      self.conjoin 'AND', other
    end
    alias_method :and, :*
    
    def | other
      self.conjoin 'OR', other
    end
    alias_method :or, :|
    
    def - other
      self.conjoin 'NOT', other
    end
    alias_method :not, :-
    
    def leafterms
      return [@tokens]
    end
    
    
    def query
      rv = {'q' => qonly}
      self.terms.each_pair do |val, arg|
        rv[arg] = val
      end
      return rv
    end
    
    def qonly terms=nil
      
      terms ||= self.terms
      
      b = @boost? '^' + @boost.to_s : ''
      
      if @op
        if @left
          return "(#{@left.qonly terms} #{@op} #{@right.qonly terms})#{b}"
        else
          return "(#{@op} #{right.qonly terms})#{b}"
        end
      else
        return self.leafnode(terms)
      end
    end
    
    
  end
  
  class Lucene < AbstractQuery
    attr_accessor :field, :boost
    attr_accessor :tokens
    
    def initialize tokens=nil, field=nil, boost=nil
      @tokens = tokens
      @field = field
      @boost = boost
      @type = "lucene"
      @lp = {}
    end
    
    def leafnode termhash
      @lp['df'] = @field if @field
      super
    end
    
    def defaultOp
      return @lp['q.op']
    end
  
    def defaultOp= val
      raise ArgumentError, "Must be 'AND' or 'OR'" unless %w(AND OR).include? val
      @lp['q.op'] = val
    end
  end
  
  # A dismax query is different in that instead of taking a single field, it takes
  # multiple field/boosts and multiple pf/boosts
  
  class DisMax < AbstractQuery
    def initialize tokens=nil, fields={}, pf = {}
      @tokens = tokens
      @fields = fields
      @pf = pf
      @type = 'dismax'
      @lp = {}
    end
    
    attr_accessor :fields, :pf
    
    def leafnode termhash
      # build field list
      # build pf list
      # do something with boost query
      super
    end
  end
    
  
end