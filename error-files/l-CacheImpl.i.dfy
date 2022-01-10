// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "../lib/Base/DebugAccumulator.i.dfy"
include "../lib/Base/Sequences.i.dfy"
include "../lib/Lang/LinearBox.i.dfy"
include "../lib/Lang/LinearBox.s.dfy"
include "../lib/Lang/LinearSequence.i.dfy"
include "../lib/DataStructures/LinearContentMutableMap.i.dfy"
include "../PivotBetree/Bounds.i.dfy"
include "NodeImpl.i.dfy"
include "BucketGeneratorImpl.i.dfy"

//
// Implements map<Reference, Node>
//

module CacheImpl {
  import DebugAccumulator
  import opened NodeImpl
  import opened Bounds
  import opened Sequences
  import opened Options
  import opened Maps
  import opened NativeTypes
  import opened BucketImpl
  import opened BucketWeights
  import opened KeyType
  import opened ValueMessage

  import BT = PivotBetreeSpec`Internal
  import Pivots = BoundedPivotsLib
  import BucketsLib

  import opened BGI = BucketGeneratorImpl

  import opened LinearBox
  import opened LinearBox_s
  import opened LinearSequence_i
  import opened LCMM = LinearContentMutableMap

  import opened LinearSequence_s

  linear datatype LMutCache = LMutCache(linear cache: LinearHashMap<Node>) {
    static method DebugAccumulate(shared c: LMutCache)
    returns (acc: DebugAccumulator.DebugAccumulator)
    requires false
    {
      acc := DebugAccumulator.EmptyAccumulator();
      var a := new DebugAccumulator.AccRec(c.cache.count, "Node");
      acc := DebugAccumulator.AccPut(acc, "cache", a);
    }
    
    predicate Inv()
    {
      && LCMM.Inv(cache)
      && (forall ref | ref in cache.contents :: cache.contents[ref].Inv())
    }

    function I() : map<BT.G.Reference, BT.G.Node>
    requires Inv()
    {
      map ref | ref in cache.contents :: cache.contents[ref].I()
    }

    function ptr(ref: BT.G.Reference) : Option<Node>
    requires Inv()
    ensures ptr(ref).None? ==> ref !in I()
    ensures ptr(ref).Some? ==>
        && ref in I()
        && ptr(ref).value.Inv()
        && I()[ref] == ptr(ref).value.I()
    {
      if ref in cache.contents then Some(cache.contents[ref]) else None
    }
  
    lemma LemmaSizeEqCount()
    requires Inv()
    ensures |I()| == |cache.contents|
    {
      assert I().Keys == cache.contents.Keys;
      assert |I()|
          == |I().Keys|
          == |cache.contents.Keys|
          == |cache.contents|;
    }

    linear inout method Insert(ref: BT.G.Reference, linear node: Node)
    requires old_self.Inv()
    requires node.Inv()
    requires |old_self.I()| <= 0x10000
    ensures self.Inv()
    ensures self.I() == old_self.I()[ref := node.I()]
    ensures forall r | r != ref :: self.ptr(r) == old_self.ptr(r)
    {
      self.LemmaSizeEqCount(); 
      shared var replaced := LCMM.Insert(inout self.cache, ref, node);
      assert self.cache.contents[ref] == node;
      assert self.Inv();

      var _ := FreeNode(node);
    }
  }
}
