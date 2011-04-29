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
    attr_accessor :search
    
    
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
    # @param [Hash] opts The options for the new query object
    # @option opts [String] :search The query string
    # @option opts [Float] :boost The boost for this query as a whole
    # @return [AbstractQuery or subclass] The new query object.
    def initialize opts={}
      @search = opts[:search]
      @boost  = opts[:boost]
      @type   = "must_be_overridden"
      @lp     = {} # the local params
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
      id = termhash[@search]
    
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
      return [@search]
    end
    
    # Combine the current query with another via the passed operator
    # @param ["AND", "OR", "NOT"] op The operator
    # @return [AbstractQuery] The new query
    
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
    
    # Unary NOT of this query (the -@ is ruby magic for a leading minus sign, e.g. '-q')
    def -@
      return self.conjoin 'NOT', nil
    end
    alias_method :not, :-@
    
    # Boolean NOT for two queries
    def - other
      self.conjoin 'NOT', other
    end
    alias_method :not, :-

    # Boolean AND of two queries
    def & other
      self.conjoin 'AND', other
    end
    alias_method :and, :&
    
    # Boolean OR of two queries
    def | other
      self.conjoin 'OR', other
    end
    alias_method :or, :|
    
    
    
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

    # The default operator ('AND' or 'OR'). Default is 'AND'
    attr_accessor :defaultOp
    
    # The default field to search
    attr_accessor :defaultField
    alias_method :field, :defaultField
    alias_method :field=, :defaultField=

    # Get a new object as per AbstractQuery#initialize and set the type
    # to 'lucene'
    # 
    # In addition to the standard parameters, also allow :defaultOp to set
    # the default operator to AND/OR
    #
    # @param [Hash] opts The options for the new query object
    # @option opts [String] :search The query string
    # @option opts [String] :fields The field to search on
    # @option opts [Float] :boost The boost for this whole query
    # @option opts ["AND", 'and', :and, 'OR', 'or', :or] :defaultOp The default operator
    # @return [Lucene] The new query object.object (or tree)

    def initialize opts={}
      super
      @type = "lucene"
      @defaultOp = opts[:defaultOp] || 'AND'
      @defaultField = opts[:defaultField] || opts[:field]
      
      # build up a complex query
    end
    
    # Set the default field, if defined, and kick it up to AbstractQuery
    def leafnode termhash
      # Should never have a compound fields hash
      @lp['df'] = @defaultField if @defaultField
      
      # Override with passed field if there was one
      field,boost = @fields.first
      if field
        @lp['df'] = field 
      end
      
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

    
    # A hash mapping containing 'solrfield' => boost pairs used in this query
    attr_accessor :fields
    
    # A hash mapping solrfields to boosts for phrase queries (same format as fields)
    attr_accessor :pf
    
    
    # Other DisMax localparams that are simple enough we can store them right in @lp
    DISMAXLOCALPARAMS = [:ps,:qs,:bf,:bq]
    
    
    ##
    # Create a new DisMax object
    #
    # @param [Hash] opts The options for the new query object    
    # @option opts [String] :search The query string
    # @option opts [Hash] :fields ({}) A hash of 'solrfield'=>boost pairs for the query
    # @option opts [Hash] :pf ({}) A hash of 'solrfield'=>boost pairs for a phrase query
    # @option opts [Float] :boost The boost for this whole query
    # @option opts [String] :mm ('100%') The 'mm' DisMax parameter for this query
    # @option opts [String] :tie ('0.1') The 'tie' DisMax parameter for this query
    # @option opts [Integer] :ps (nil) The 'ps' DisMax parameter for this query
    # @option opts [Integer] :qs (nil) The 'qs' DisMax parameter for this query
    # @see http://wiki.apache.org/solr/DisMaxQParserPlugin General description of DisMax parameters
    # @see http://wiki.apache.org/solr/SolrRelevancyFAQ#How_can_I_search_for_one_term_near_another_term_.28say.2C_.22batman.22_and_.22movie.22.29 Description and examples of the ps and qs parameters
    # @see http://lucene.apache.org/solr/api/org/apache/solr/util/doc-files/min-should-match.html Extended information about 'mm'

    def initialize opts={}
      @search  = opts[:search]
      @boost   = opts[:boost]
      @fields  = opts[:fields] || {}
      @pf      = opts[:pf] || {}
      @boost   = opts[:boost]
      @type    = "dismax"
      
      @lp      = {} # the local params
      @lp['mm']  = opts[:mm]  || '100%'
      @lp['tie'] = opts[:tie] || '0.01'
      
      # Set other dismax localparams
      OTHERPARAMS.each do |p|
        @lp[p.to_s] = opts[p] if opts[p]
      end
    end
    
    # Capture calls to set other localparams
    def method_missing
    
    # Set the mm param. I supposed I could make a nice object for it...
    # @see http://lucene.apache.org/solr/api/org/apache/solr/util/doc-files/min-should-match.html
    def mm= mm
      @lp['mm'] = mm
    end
    
    # Constructs the qf/pf strings and adds them to the localparams (@lp) hash, and 
    # then kicks it up to AbstractQuery
    # @see AbstractQuery#leafnode
    def leafnode termhash
      @lp['qf'] = fields.each_pair.map {|k,v| "#{k}^#{v}"}.join(' ') if fields.size > 0
      @lp['pf'] = pf.each_pair.map {|k,v| "#{k}^#{v}"}.join(' ') if pf.size > -0
      
      # do something with boost query
      super
    end
  end
    
  
end