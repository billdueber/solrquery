require 'uri'

module SolrQuery

  # The abstract superclass for different types of solr queries.
  #    
  # We're really overloading this class to be either a leaf node
  # (with an actual query) or an internal node (with an operator and one
  # or two child notes, each of which might also be either a leaf or a
  # tree)

  class AbstractQuery
    
    # For a leaf, the tokens to seach on. Could be compled (e.g., with quotes)
    attr_accessor :tokens
    
    # A hash mapping 'solrfield' => boost.
    attr_accessor :fields
    
    # How much to boost this particular query (leaf or tree)
    attr_accessor :boost

    # The operator (AND/OR/NOT)
    attr_accessor :op
    
    # The left side of the binary operator (AND/OR)
    attr_accessor :left
    
    # The right side of the binary operator (AND/OR/NOT)
    attr_accessor :right
    
    # Local parameters
    attr_accessor :lp
    
    ##
    # Initialize the query object.
    # 
    # @option opts [String] :tokens The query string
    # @option opts [String] :fields The field to search on
    # @option opts [Float] :boost The boost for this whole query
    # @return [AbstractQuery or subclass] The new query object.
    def initialize opts={}
      @tokens = opts[:tokens]
      @fields = opts[:fields] || {}
      @boost = opts[:boost]
      @type = "must_be_overridden"
      @lp = {} # the local params
    end
    
    # Take a hash that maps termstring to URL arguments and return 
    # a string that will go in the URL (not yet URL-encoded) based on it
    # for this query type. The reason to use the termhash is so you can have
    # multiple queries all using the same terms, e.g.
    #     http://...?q=_query_:"{!lucene df='author1' v=$q1}" OR _query_:"{!lucene df='author2' v=$q1}"&q1=my search terms
    #
    # This default method takes care of anything in the @lp (localParams) and a basic boost
    #
    # Everything in the termhash gets turned into URL components, so if you need to stick extra
    # stuff in there, you can (for, e.g., boost queries)
    #
    # @param [Hash] termhash A hash mapping search strings to q1/q2/etc. -- the output of
    # self.terms

    def leafnode termhash
      b = @boost? '^' + @boost.to_s : ''
      id = termhash[@tokens]
    
      args = @lp.each.map{|k,v| "#{k}='#{v}'"}.join(' ')
      
      args = ' ' + args if args != ''
      return "_query_:\"{!#{@type}#{args} v=$#{id}}\"#{b}"
    end
    
    
    # In the default case (inner == false) on a tree, walk the query tree and get a hash of 
    # token strings (the actual queries, as opposed to the fields, booleans, etc.). 
    # mapped to arbitrary identifiers (in this implementation, q1, q2, q3, ...)]
    # 
    # In the recursive call (inner == true) on tree, walk the tree and build
    # up a (nonunique) array of tokenstrings. This is what the nonrecursive call
    # deduplicates and turns into the eventual return Hash.
    # 
    # Called against a leaf node, just return the tokenstring(s) from the leaf
    # 
    # Basically, call it with inner==false on the node you want to 
    # get the termlist for.
    # 
    # @param [Boolean] inner Flag indicating whether this is a top-level call (inner == false)
    # or a recursive call (inner == true)
    # return [Hash, Array] Either an array of tokenstring (inner==true) or a hash mapping
    # arbitrary ids (q1,q2) to those tokenstrings
    
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
    
    # Return the set of tokenstrings for this leaf node
    # @return [Array<String>] The tokenstrings for this node
    def leafterms
      return [@tokens]
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
    
    def & other
      self.conjoin 'AND', other
    end
    alias_method :and, :&
    
    def | other
      self.conjoin 'OR', other
    end
    alias_method :or, :|
    
    def - other
      self.conjoin 'NOT', other
    end
    alias_method :not, :-
    
    
    # A string suitable for dropping onto the end of a solr URL to do the query
    # 
    # @return [String] an already-URI-encoded string of the form q=_query_:"..."&q1=term2 term3&...
    def as_URL_snippet
      return self.query.map{|k,v| "#{k}=>#{URI.escape(v)}"}.join('&')
    end
    
    
    # The query is a hash that includes both the q parameter and all the id=>tokenstring
    # pairs. 
    # @return [Hash] A hash of the form {q=>"<long query>", q1=>"tokenstring1", ...}
    def query
      rv = {'q' => query_without_terms}
      self.terms.each_pair do |val, arg|
        rv[arg] = val
      end
      return rv
    end
    
    # The full query with the tokenstrings replaced by the appropriate 
    # q1, q2, etc. You end up with something like
    #  _query_:"{!lucene val=q1} AND {!dismax ...}"
    # 
    # @param [Hash] terms The mapping of q1/q2/... to tokenstrings
    
    def query_without_terms terms=self.terms
      
      b = @boost? '^' + @boost.to_s : ''
      
      if @op
        if @left
          return "(#{@left.query_without_terms terms} #{@op} #{@right.query_without_terms terms})#{b}"
        else
          return "(#{@op} #{right.query_without_terms terms})#{b}"
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

    attr_accessor :fields, :pf
    
    
    def initialize tokens=nil, fields={}, pf = {}
      @tokens = tokens
      @fields = fields
      @pf = pf
      @type = 'dismax'
      @lp = {}
    end
    
    
    def leafnode termhash
      @lp['qf'] = fields.each_pair.map {|k,v| "#{k}^#{v}"}.join(' ') if fields.size > 0
      @lp['pf'] = pf.each_pair.map {|k,v| "#{k}^#{v}"}.join(' ') if pf.size > -0
      # do something with boost query
      super
    end
  end
    
  
end