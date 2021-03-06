require 'spec_helper'
require 'pp'

describe "Interal ops" do
  describe "A simple Lucene query" do
    it "with one term" do
      q = SolrQuery::Lucene.new :search=>"solr"
      query = q.query
      qmatch = /_query_:"\{!lucene v=\$(q\d+)\}"/
      query['q'].must_match qmatch
      query['q'] =~  qmatch
      query[$1].must_equal 'solr'
    end
    
    it "with multiple terms" do
      q = SolrQuery::Lucene.new :search=>"solr apache"
      query = q.query
      qmatch = /_query_:"\{!lucene v=\$(q\d+)\}"/
      query['q'].must_match qmatch
      query['q'] =~  qmatch
      query[$1].must_equal 'solr apache'
    end
    
  
    it "with a boost" do
      q = SolrQuery::Lucene.new :search=>"solr apache"
      q.boost = 3
      q.query['q'].must_match /_query_:"\{!lucene v=\$q(\d+)\}"\^3/
    end
      
    it "with a field" do
      q = SolrQuery::Lucene.new :search=>'solr', :fields=>{'title' => 1}
      q.query['q'].must_match /_query_:"\{!lucene df='title' v=\$q(\d+)\}"/
    end
      
    it "with all three" do
      q = SolrQuery::Lucene.new :search=>%w(solr apache), :field=>'title', :boost=>3
      q.query['q'].must_match /_query_:"{!lucene df='title' v=\$q(\d+)}"\^3/
    end
      
    it "uses default boolean operator" do
      q = SolrQuery::Lucene.new :search=>%w(solr apache), :field=>'title', :boost=>3
      q.defaultOp = 'AND'
      q.query['q'].must_match /_query_:"\{!lucene q.op='AND' df='title'\s+v=\$q(\d+)\}"\^3/
      q.defaultOp = 'OR'
      q.query['q'].must_match /_query_:"\{!lucene q.op='OR' df='title'\s+v=\$q(\d+)\}"\^3/
    end
      
    it "rejects a non-AND/OR boolean" do
      q = SolrQuery::Lucene.new :search=>%w(solr apache), :fields=>{'title' => 3}
      lambda {q.defaultOp = 'NOT'}.must_raise ArgumentError
    end
      
    it "uses a default field" do
      q = SolrQuery::Lucene.new :search=>%w(solr apache), :boost=> 3
      q.defaultField = 'all'
      q.query['q'].must_match /_query_:"\{!lucene df='all' v=\$q(\d+)\}"\^3/
    end
      
    it "can deal with a null field and positive boost" do
      q = SolrQuery::Lucene.new :search=>%w(solr apache), :boost=>3
      q.query['q'].must_match /_query_:"\{!lucene v=\$q(\d+)\}"\^3/
    end
  end
  
  
  describe "A simple DisMax query" do
    it 'with one term' do
      q = SolrQuery::DisMax.new "solr", {'all' => 100, 'title' => 200}
      query = q.query
      query['q0'].must_equal 'solr'
      query['q'].must_match /\{\!dismax qf='all\^100 title\^200' v=\$q0\}/
    end
  end
  
end



