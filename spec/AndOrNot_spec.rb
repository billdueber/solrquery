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
  end

  it "can AND together two queries" do
    query = (@q1 * @q2).query
    qmatch = /\(_query_:"{!lucene\s+df='name'\s+v=\$(q\d+)}"\^3\s+
               AND\s+
                _query_:"{!lucene\s+v=\$(q\d+)}"\)/x
    query['q'].should match qmatch
    query['q'] =~ qmatch
    pp query
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
