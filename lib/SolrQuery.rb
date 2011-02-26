module SolrQuery
    
  class AbstractQuery
    
    attr_accessor :op, :left, :right, :wt, :fl, :q
    
    def initialize q=nil
      @q = q
    end
    
    def qstring
      "Abstract class -- override!"
    end
    
    
    def to_s
      if @q
        "#{@qstring}"
      else
        "(#{left} #{op} #{right})"
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
    
    def defaultOp= val
      raise ArgumentError, "Must be 'AND' or 'OR'" unless %w(AND OR).include? val
      @lp['q.op'] = val
    end
    
    
    def -@
      return self.conjoin 'NOT', nil
    end
    
    def * other
      self.conjoin 'AND', other
    end
    alias_method :and, :*
    
    def / other
      self.conjoin 'OR', other
    end
    alias_method :or, :/
    
    def - other
      self.conjoin 'NOT', other
    end
    alias_method :not, :-
    
  end
  
  class Lucene < AbstractQuery
    attr_accessor :field, :terms, :boost
    
    def initialize terms=nil, field=nil, boost=nil
      @terms = Array(terms)
      @field = field
      @boost = boost
      @type = "lucene"
      @lp = {}
    end
    
    def defaultOp
      return @lp['q.op']
    end
            
    def to_s
      
      if @op
        if @left
          return "(#{@left} #{@op} #{@right})"
        else
          return "(#{@op} #{right})"
        end
      else
    
        @lp['df'] = @field if @field
        
      
        boost = ''
        boost = "^#{@boost}" if @boost
      
        id = 'q' + @terms.object_id.to_s
        terms = "#{@terms.join(' ')}"
      
        args = @lp.each.map{|k,v| "#{k}='#{v}'"}.join(' ')
        
        args = ' ' + args if args != ''

      
        "_query_:\"{!#{@type}#{args} v=$#{id}}\"#{boost}&#{id}=#{terms}"
      end
    end

  end
end