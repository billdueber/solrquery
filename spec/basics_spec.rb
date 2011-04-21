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
  
  
  describe "A simple DisMax query" do
    it 'with one term' do
      q = SolrQuery::DisMax.new "solr", {'all' => 100, 'title' => 200}
      query = q.query
      query['q0'].should == 'solr'
      query['q'].should match /\{\!dismax qf='all\^100 title\^200' v=\$q0\}/
    end
  end
  
end



