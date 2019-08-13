
function solrpanel() {
  ssh -L $1:localhost:$2 $3
}
