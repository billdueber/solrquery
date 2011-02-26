require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "A simple Lucene query" do
  it "with one term" do
    q = SolrQuery::Lucene.new "solr"
    q.to_s.should match /_query_:"\{!lucene v=\$q(\d+)\}"&q\1=solr/
  end
  it "with multiple terms" do
    q = SolrQuery::Lucene.new "solr apache"
    q.to_s.should match /_query_:"\{!lucene v=\$q(\d+)\}"&q\1=solr apache/
  end
  
  it "with a boost" do
    q = SolrQuery::Lucene.new "solr apache"
    q.boost = 3
    q.to_s.should match /_query_:"\{!lucene v=\$q(\d+)\}"\^3&q\1=solr apache/
  end
  
  it "with multiple terms in an array" do
    q = SolrQuery::Lucene.new ['solr', 'apache']
    q.to_s.should match /_query_:"\{!lucene v=\$q(\d+)\}"&q\1=solr apache/
  end
    
  it "with a field" do
    q = SolrQuery::Lucene.new 'solr', 'title'
    q.to_s.should match /_query_:"\{!lucene df='title' v=\$q(\d+)\}"&q\1=solr/
  end
  
  it "with all three" do
    q = SolrQuery::Lucene.new %w(solr apache), 'title', 3
    q.to_s.should match /_query_:"\{!lucene df='title' v=\$q(\d+)\}"\^3&q\1=solr apache/
  end
  
  it "uses default boolean operator" do
    q = SolrQuery::Lucene.new %w(solr apache), 'title', 3
    q.defaultOp = 'AND'
    q.to_s.should match /_query_:"\{!lucene q.op='AND' df='title'\s+v=\$q(\d+)\}"\^3&q\1=solr apache/
    q.defaultOp = 'OR'
    q.to_s.should match /_query_:"\{!lucene q.op='OR' df='title'\s+v=\$q(\d+)\}"\^3&q\1=solr apache/
  end
  
  it "rejects a non-AND/OR boolean" do
    q = SolrQuery::Lucene.new %w(solr apache), 'title', 3
    lambda {q.defaultOp = 'NOT'}.should raise_error
  end
  
  it "uses a default field" do
    q = SolrQuery::Lucene.new %w(solr apache), 'title', 3
    q.field = 'all'
    q.to_s.should match /_query_:"\{!lucene df='all' v=\$q(\d+)\}"\^3&q\1=solr apache/
  end
  
  it "can deal with a null field and positive boost" do
    q = SolrQuery::Lucene.new %w(solr apache), nil, 3
    q.to_s.should match /_query_:"\{!lucene v=\$q(\d+)\}"\^3&q\1=solr apache/
  end
  
end


describe "A negated lucene query" do
  it "does a simple query" do
    q = SolrQuery::Lucene.new 'solr', 'title'
    (-q).to_s.should match /\(NOT _query_:"\{!lucene df='title' v=\$q(\d+)\}"&q\1=solr\)/
  end
end

describe "A compound lucene query" do
  before(:each) do
    @q1 =   SolrQuery::Lucene.new 'solr', 'name', 3
    @q2 =   SolrQuery::Lucene.new 'apache'
  end
  
  it "will AND two queries" do
    (@q1 * @q2).to_s.should == '(_query_:"{!lucene}name:(solr)^3" AND _query_:"{!lucene}(apache)")'
  end
  
  it 'will OR two queries' do
    (@q1 / @q2).to_s.should == '(_query_:"{!lucene}name:(solr)^3" OR _query_:"{!lucene}(apache)")'
    puts (@q1 / @q2).to_s
  end
  
  it 'recognizes the .and and .or methods' do
    (@q1.and @q2).to_s.should == '(_query_:"{!lucene}name:(solr)^3" AND _query_:"{!lucene}(apache)")'
    (@q1.or  @q2).to_s.should == '(_query_:"{!lucene}name:(solr)^3" OR _query_:"{!lucene}(apache)")'
  end
end

# describe "A multifield lucene query" do
#   it "accepts a set of field/boost values" do
#     q = SolrQuery::LuceneMF.new {'name'=>10, 'keyword'=>1}, ['solr', 'apache']
#     q.to_s.should == '_query_:"{!lucene}name:(solr apache)^10 keyword:(solr apache)^1"'
#   end
# end