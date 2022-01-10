include "../lib/Base/DebugAccumulator.i.dfy"
include "NodeImpl.i.dfy"
//
// Implements map<Reference, Node>
//
// TODO(thance): We need a CacheModel, because this is taking too big a leap
// from map<Reference, Node>.
//

module CacheImpl {
  import DebugAccumulator
  import opened NodeImpl
  import opened Options
  import opened Maps
  import opened NativeTypes
  import opened BucketImpl
  import opened BucketWeights
  import opened KeyType
  import opened ValueMessage
  import NodeModel

  class MutCache
  {
    var cache: MM.ResizingHashMap<Node>;
    ghost var Repr: set<object>;

    method DebugAccumulate()
    returns (acc:DebugAccumulator.DebugAccumulator)
    requires false
    {
      acc := DebugAccumulator.EmptyAccumulator();
      var a := new DebugAccumulator.AccRec(cache.Count, "Node");
      acc := DebugAccumulator.AccPut(acc, "cache", a);
    }

    constructor()
    ensures Inv();
    ensures I() == map[]
    ensures fresh(Repr);
    {
      cache := new MM.ResizingHashMap(128);
      new;
      Repr := {this} + cache.Repr + MutCacheBucketRepr();
    }

    protected function MutCacheBucketRepr() : set<object>
    reads this, cache
    reads set ref | ref in cache.Contents :: cache.Contents[ref]
    {
      set ref, o | ref in cache.Contents && o in cache.Contents[ref].Repr :: o
    }

    protected predicate Inv()
    reads this, Repr
    ensures Inv() ==> this in Repr
    {
      && cache in Repr
      && (forall ref | ref in cache.Contents :: cache.Contents[ref] in Repr)
      && Repr == {this} + cache.Repr + MutCacheBucketRepr()
      && (forall ref | ref in cache.Contents :: cache.Contents[ref].Repr !! cache.Repr)
      && (forall ref | ref in cache.Contents :: this !in cache.Contents[ref].Repr)
      && this !in cache.Repr
      && cache.Inv()
      && (forall ref | ref in cache.Contents :: cache.Contents[ref].Inv())
    }

    protected function I() : map<BT.G.Reference, IM.Node>
    reads this, Repr
    requires Inv()
    {
      map ref | ref in cache.Contents :: cache.Contents[ref].I()
    }

    protected function ptr(ref: BT.G.Reference) : Option<Node>
    reads Repr
    requires Inv()
    ensures ptr(ref).None? ==> ref !in I()
    ensures ptr(ref).Some? ==>
        && ref in I()
        && ptr(ref).value.Inv()
        && I()[ref] == ptr(ref).value.I()
    {
      if ref in cache.Contents then Some(cache.Contents[ref]) else None
    }

    method GetOpt(ref: BT.G.Reference)
    returns (node: Option<Node>)
    requires Inv()
    ensures node == ptr(ref)
    {
      node := cache.Get(ref);
    }

    lemma LemmaNodeReprLeRepr(ref: BT.G.Reference)
    requires Inv()
    ensures ptr(ref).Some? ==> ptr(ref).value.Repr <= Repr
    {
    }

    lemma LemmaSizeEqCount()
    requires Inv()
    ensures |I()| == |cache.Contents|
    {
      assert I().Keys == cache.Contents.Keys;
      assert |I()|
          == |I().Keys|
          == |cache.Contents.Keys|
          == |cache.Contents|;
    }

    method Insert(ref: BT.G.Reference, node: Node)
    requires Inv()
    requires node.Inv()
    requires Repr !! node.Repr
    requires |I()| <= 0x10000
    modifies Repr
    ensures Inv()
    ensures I() == old(I()[ref := node.I()])
    ensures forall r | r != ref :: ptr(r) == old(ptr(r))
    ensures forall o | o in Repr :: o in old(Repr) || o in old(node.Repr) || fresh(o)
    {
      LemmaSizeEqCount();

      cache.Insert(ref, node);

      assert cache.Contents[ref] == node;
      Repr := {this} + cache.Repr + MutCacheBucketRepr();

      assert Inv();
    }
  }
}
