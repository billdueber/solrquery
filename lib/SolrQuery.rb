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
    attr_accessor :field, :boost
    attr_accessor :tokens
    
    def initialize tokens=nil, field=nil, boost=nil
      @tokens = tokens
      @field = field
      @boost = boost
      @type = "lucene"
      @lp = {}
    end
    
    
    def defaultOp
      return @lp['q.op']
    end
    
    def terms inner = nil
      t = []
      if @op
        t += @left.terms(true) + @right.terms(true)
      else 
        t = [@tokens]
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
        @lp['df'] = @field if @field

        id = terms[@tokens]
      
        args = @lp.each.map{|k,v| "#{k}='#{v}'"}.join(' ')
        
        args = ' ' + args if args != ''
        return "_query_:\"{!#{@type}#{args} v=$#{id}}\"#{b}"

      end
    end

  end
end