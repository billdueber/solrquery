require 'spec_helper'
require 'pp'

describe "Interal ops" do
  describe "A simple Lucene query" do
    it "with one term" do
      q = SolrQuery::Lucene.new "solr"
      query = q.query
      qmatch = /_query_:"\{!lucene v=\$(q\d+)\}"/
      query['q'].should match qmatch
      query['q'] =~  qmatch
      query[$1].should == 'solr'
    end
    
    it "with multiple terms" do
      q = SolrQuery::Lucene.new "solr apache"
      query = q.query
      qmatch = /_query_:"\{!lucene v=\$(q\d+)\}"/
      query['q'].should match qmatch
      query['q'] =~  qmatch
      query[$1].should == 'solr apache'
    end
    
  
    it "with a boost" do
      q = SolrQuery::Lucene.new "solr apache"
      q.boost = 3
      q.query['q'].should match /_query_:"\{!lucene v=\$q(\d+)\}"\^3/
    end
      
    it "with a field" do
      q = SolrQuery::Lucene.new 'solr', 'title'
      q.query['q'].should match /_query_:"\{!lucene df='title' v=\$q(\d+)\}"/
    end
      
    it "with all three" do
      q = SolrQuery::Lucene.new %w(solr apache), 'title', 3
      q.query['q'].should match /_query_:"{!lucene df='title' v=\$q(\d+)}"\^3/
    end
      
    it "uses default boolean operator" do
      q = SolrQuery::Lucene.new %w(solr apache), 'title', 3
      q.defaultOp = 'AND'
      q.query['q'].should match /_query_:"\{!lucene q.op='AND' df='title'\s+v=\$q(\d+)\}"\^3/
      q.defaultOp = 'OR'
      q.query['q'].should match /_query_:"\{!lucene q.op='OR' df='title'\s+v=\$q(\d+)\}"\^3/
    end
      
    it "rejects a non-AND/OR boolean" do
      q = SolrQuery::Lucene.new %w(solr apache), 'title', 3
      lambda {q.defaultOp = 'NOT'}.should raise_error
    end
      
    it "uses a default field" do
      q = SolrQuery::Lucene.new %w(solr apache), 'title', 3
      q.field = 'all'
      q.query['q'].should match /_query_:"\{!lucene df='all' v=\$q(\d+)\}"\^3/
    end
      
    it "can deal with a null field and positive boost" do
      q = SolrQuery::Lucene.new %w(solr apache), nil, 3
      q.query['q'].should match /_query_:"\{!lucene v=\$q(\d+)\}"\^3/
    end
  end
end

describe "A compound lucene query" do
  before(:each) do
    @q1 =   SolrQuery::Lucene.new 'solr', 'name', 3
    @q2 =   SolrQuery::Lucene.new 'apache'
  end

  it "can AND together two queries" do
    query = (@q1 * @q2).query
    qmatch = /\(_query_:"{!lucene\s+df='name'\s+v=\$(q\d+)}"\^3\s+
               AND\s+
                _query_:"{!lucene\s+v=\$(q\d+)}"\)/x
    query['q'].should match qmatch
    query['q'] =~ qmatch
    query[$1].should == 'solr'
    query[$2].should == 'apache'
  end
  
  it "can AND together two queries and use a boost" do
    q = (@q1 * @q2)
    q.boost = 10
    query = q.query
    qmatch = /\(_query_:"{!lucene\s+df='name'\s+v=\$(q\d+)}"\^3\s+
               AND\s+
                _query_:"{!lucene\s+v=\$(q\d+)}"\)\^10/x
    query['q'].should match qmatch
    query['q'] =~ qmatch
    query[$1].should == 'solr'
    query[$2].should == 'apache'
  end  
end

    
# 
# 
#   describe "A negated lucene query" do
#     it "does a simple query" do
#       q = SolrQuery::Lucene.new 'solr', 'title'
#       (-q).to_s.should match /\(NOT _query_:"\{!lucene df='title' v=\$q(\d+)\}"&q\1=solr\)/
#     end
#   end
# end


# 
#   describe "A compound lucene query" do
#     before(:each) do
#       @q1 =   SolrQuery::Lucene.new 'solr', 'name', 3
#       @q2 =   SolrQuery::Lucene.new 'apache'
#     end
#   
#     it "with AND two queries" do
#     
#       # Need to tease out the $q1234 from the actual queries and only and the queries
#       # Maybe a "compound" method that returns the query and terms as separate fields?
#     
#       (@q1 * @q2).to_s.should match /_query_:"\{!lucene\s+df='name'\s+v=\$q(\d+)\}"\^3
#                                                 &q\1=solr\s+AND\s+/
#     end                                            
#     
#   
#     it 'with OR two queries' do
#       (@q1 / @q2).to_s.should == '(_query_:"{!lucene}name:(solr)^3" OR _query_:"{!lucene}(apache)")'
#       puts (@q1 / @q2).to_s
#     end
#   
#     it 'recognizes the .and and .or methods' do
#       (@q1.and @q2).to_s.should == '(_query_:"{!lucene}name:(solr)^3" AND _query_:"{!lucene}(apache)")'
#       (@q1.or  @q2).to_s.should == '(_query_:"{!lucene}name:(solr)^3" OR _query_:"{!lucene}(apache)")'
#     end
#   end
# 
#   # describe "A multifield lucene query" do
#   #   it "accepts a set of field/boost values" do
#   #     q = SolrQuery::LuceneMF.new {'name'=>10, 'keyword'=>1}, ['solr', 'apache']
#   #     q.to_s.should == '_query_:"{!lucene}name:(solr apache)^10 keyword:(solr apache)^1"'
#   #   end
#   # end

# describe "Live Solr tests" do
#   before(:all) do
#     puts "TRYING TO LOAD STUFF!"
#     require 'jruby_streaming_update_solr_server'
#     Dir.glob('spec/jars/used/*.jar') {|f| require f}
#     sd = 'spec/solr'
#     Java::Java.lang.System.setProperty('solr.solr.home', sd)
#     initializer = Java::org.apache.solr.core.CoreContainer::Initializer.new
#     @cc = initializer.java_send(:initialize)
#     @server = Java::org.apache.solr.client.solrj.embedded.EmbeddedSolrServer.new(@cc, '')  
#     include_class Java::org.apache.solr.client.solrj.SolrQuery
#     @q = SolrQuery.new
#   end  
#   
#   after(:all) do
#     @cc.shutdown
#   end  
# 
#   before(:each) do
#     @server.deleteByQuery('*:*')
#     @server.commit
#   end
# 
#   
#   it "brings up the solr server" do
#     doc = SolrInputDocument.new
#     doc['id'] = 'one'
#     doc['name'] = 'Hello there'
#     @server.add(doc)
#     @server.commit
#     q = SolrQuery.new 
#     q.setQuery('id:one')
#     rsp = @server.query(q)
#     rsp.results[0]['name'].should == 'Hello there'
#   end
# 
# end


