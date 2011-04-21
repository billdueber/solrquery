describe "A negated lucene query" do
  it "does a simple query" do
    q = SolrQuery::Lucene.new 'solr', 'title'
    (-q).query['q'].should match /\(NOT _query_:"\{!lucene df='title' v=\$q(\d+)\}"\)/
  end
end



describe "A compound lucene query" do
  before(:each) do
    @q1 =   SolrQuery::Lucene.new 'solr', 'name', 3
    @q2 =   SolrQuery::Lucene.new 'apache'
    @q3 =   SolrQuery::Lucene.new 'three'
    @q4 =   SolrQuery::Lucene.new 'four', 'name', 4
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
  
  it "can OR two queries" do
    query = (@q1 | @q2).query
    
    qmatch = /\(_query_:"{!lucene\s+df='name'\s+v=\$(q\d+)}"\^3\s+
               OR\s+
                _query_:"{!lucene\s+v=\$(q\d+)}"\)/x
    query['q'].should match qmatch
    query['q'] =~ qmatch
    query[$1].should == 'solr'
    query[$2].should == 'apache'
  end
    
end

describe "A compound dismax query" do
  before(:each) do
    @q1 =   SolrQuery::DisMax.new 'kwone', {'one'=>10, 'oneone'=>11}
    @q2 =   SolrQuery::DisMax.new 'kwtwo', {'twp' => 2}
    @q3 =   SolrQuery::DisMax.new 'kwthree', {'three'=>3}
    @q4 =   SolrQuery::DisMax.new 'kwfour', {'four'=>4}, {'pffour'=>444}
  end

  it "should work" do
    pp (@q1 | (@q3 * @q4)).query
  end
end