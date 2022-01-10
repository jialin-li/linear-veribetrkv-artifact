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
// TODO(thance): We need a CacheModel, because this is taking too big a leap
// from map<Reference, Node>.
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


// begin generated export
  export Spec
    provides *
    reveals LMutCache, LMutCache.Inv, LMutCache.ptr, LMutCache.I, CacheCount
  export extends Spec
// end generated export

  linear datatype LMutCache = LMutCache(linear cache: LinearHashMap<Node>) {
    static method DebugAccumulate(shared c: LMutCache)
    returns (acc: DebugAccumulator.DebugAccumulator)
    requires false
    {
      acc := DebugAccumulator.EmptyAccumulator();
      var a := new DebugAccumulator.AccRec(c.cache.count, "Node");
      acc := DebugAccumulator.AccPut(acc, "cache", a);
    }

    static method NewCache() returns (linear newcache: LMutCache)
    ensures newcache.Inv()
    ensures newcache.I() == map[]
    {
      linear var cache := LCMM.Constructor(128);
      newcache := LMutCache(cache);
    }
    
    predicate Inv()
    {
      && LCMM.Inv(cache)
      && (forall ref | ref in cache.contents :: cache.contents[ref].Inv())
    }

    // [yizhou7]: free method is tricker than I thought
    // linear method Free()
    //   requires Inv()
    // {
    //   linear var LMutCache(cache) := this;
    //   linear var LinearHashMap(underlying, _, _) := cache;
    //   linear var FixedSizeLinearHashMap(storage, _, _) := underlying;

    //   var j : uint64 := 0;

    //   assume lseq_has_all(storage);
    //   assume |lseqs(storage)| <= 0xffff_ffff_ffff_ffff;

    //   var len := lseq_length_as_uint64(storage);

    //   while j < len
    //     invariant |lseqs(storage)| == len as int;
    //     invariant |lseq_has(storage)| == len as int;
    //     invariant 0 <= j <= len;
    //     invariant forall i :: j <= i < len ==> lseq_has(storage)[i]
    //     invariant forall k :: 0 <= k < j ==> !lseq_has(storage)[k]
    //   {
    //     linear var item;
    //     assert lseq_has(storage)[j];
    //     assert j as nat < |storage|;

    //     storage, item := lseq_take(storage, j);
    //     linear match item {
    //       case Entry(_, node) => {
    //         assume node.Inv();
    //         var _ := FreeNode(node);
    //       }
    //       case Empty() => { }
    //       case Tombstone(_) => { }
    //     }
    //     j := j + 1;
    //   }
  
    //   forall i:nat | i < |storage|
    //   ensures i !in storage
    //   {
    //     assert !lseq_has(storage)[i] by {
    //       assert forall i :: 0 <= i < len ==> !lseq_has(storage)[i];
    //     }
    //   }

    //   lseq_free(storage);
    // }

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

    shared method InCache(ref: BT.G.Reference) returns (b: bool)
    requires Inv()
    ensures b == ptr(ref).Some?
    {
      b := IsEntry(cache.underlying, ref);
    }

    shared method Get(ref: BT.G.Reference)
    returns (shared node: Node)
    requires Inv()
    requires ptr(ref).Some?
    ensures node == ptr(ref).value
    {
      node := LCMM.Get(cache, ref);
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
      linear var replaced := LCMM.Insert(inout self.cache, ref, node);
      linear match replaced {
        case lSome(oldnode) => {
          var _ := FreeNode(oldnode);
        }
        case lNone() => { }
      }
      assert self.cache.contents[ref] == node;
      assert self.Inv();
    }

    linear inout method ReplaceAndGet(ref: BT.G.Reference, linear newNode: Node)
    returns (linear oldNode: Node)
    requires old_self.Inv()
    requires old_self.ptr(ref).Some?
    requires |old_self.I()| <= 0x10000
    requires newNode.Inv()
    ensures self.Inv()
    ensures oldNode.Inv()
    ensures |self.I()| == |old_self.I()|
    ensures oldNode == old_self.ptr(ref).value
    ensures self.I() == old_self.I()[ref := newNode.I()]
    ensures forall r | r != ref :: self.ptr(r) == old_self.ptr(r)
    {
      self.LemmaSizeEqCount();

      linear var replaced := LCMM.Insert(inout self.cache, ref, newNode);
      assert replaced.lSome?;
      linear var lSome(node) := replaced;
      oldNode := node;

      assert self.cache.contents[ref] == newNode;
      assert self.Inv();

      self.LemmaSizeEqCount();
    }

    linear inout method RemoveAndGet(ref: BT.G.Reference) returns (linear node: Node)
    requires old_self.Inv()
    requires old_self.ptr(ref).Some?
    ensures self.Inv()
    ensures node.Inv()
    ensures node == old_self.ptr(ref).value
    ensures self.I() == MapRemove1(old_self.I(), ref)
    {
      self.LemmaSizeEqCount();
      linear var removed := LCMM.Remove(inout self.cache, ref);
      assert removed.lSome?;
      linear var lSome(value) := removed;
      node := value;
      assert self.Inv();
    }

    linear inout method Remove(ref: BT.G.Reference)
    requires old_self.Inv()
    ensures self.Inv()
    ensures self.I() == MapRemove1(old_self.I(), ref)
    {
      self.LemmaSizeEqCount();
      linear var removed := LCMM.Remove(inout self.cache, ref);
      linear match removed {
        case lSome(node) => {
          assert node.Inv();
          var _ := FreeNode(node);
        }
        case lNone() => { }
      }
      assert self.Inv();
    }

    // This is used for the 'grow' operation.
    linear inout method MoveAndReplace(oldref: BT.G.Reference,
      newref: BT.G.Reference, linear node: Node)
    requires old_self.Inv()
    requires node.Inv()
    requires |old_self.I()| <= 0x10000
    requires oldref in old_self.I()
    ensures self.Inv()
    ensures self.I() == old_self.I()[oldref := node.I()][newref := old_self.I()[oldref]]
    ensures newref !in old_self.I() ==> |self.I()| == |old_self.I()| + 1;
    ensures newref in old_self.I() ==> |self.I()| == |old_self.I()|;
    ensures self.I().Keys == old_self.I().Keys + {newref};
    {
      self.LemmaSizeEqCount();
      linear var replaced := LCMM.Insert(inout self.cache, oldref, node);
      assert self.cache.contents[oldref] == node;
      assert replaced.lSome?;

      self.LemmaSizeEqCount();
      assert |self.I()| == |old_self.I()|;

      linear var lSome(oldnode) := replaced;
      linear var replaced2 := LCMM.Insert(inout self.cache, newref, oldnode);
      linear match replaced2 {
        case lSome(n) => {
          var _ := FreeNode(n);
        }
        case lNone() => { }
      }

      self.LemmaSizeEqCount();
    }

    // Like Insert, but with slightly different requires
    linear inout method Overwrite(ref: BT.G.Reference, linear node: Node)
    requires old_self.Inv()
    requires node.Inv()
    requires ref in old_self.I()
    requires |old_self.I()| <= 0x10000
    ensures self.Inv()
    ensures self.I() == old_self.I()[ref := node.I()]
    {
      inout self.Insert(ref, node);
    }

    linear inout method NodeUpdateSlot(ref: BT.G.Reference, slot: uint64, 
      linear bucket: MutBucket, childref: BT.G.Reference)
    returns (newchildren: Option<seq<BT.G.Reference>>)
    requires old_self.Inv()
    requires bucket.Inv()
    requires old_self.ptr(ref).Some?
    requires BT.WFNode(old_self.I()[ref])
    requires |old_self.I()| <= 0x10000
    requires old_self.I()[ref].children.Some?
    requires slot as int + 1 < 0x1_0000_0000_0000_0000
    requires slot as nat < |old_self.I()[ref].children.value|
    ensures self.Inv()
    ensures self.I() == old_self.I()[ref := BT.G.Node(
        old_self.I()[ref].pivotTable,
        Some(old_self.I()[ref].children.value[slot as int := childref]),
        old_self.I()[ref].buckets[slot as int := bucket.bucket]
      )]
    ensures newchildren == self.I()[ref].children
    {
      linear var node := inout self.RemoveAndGet(ref);
      inout node.UpdateSlot(slot, bucket, childref);
      newchildren := node.children;
      inout self.Insert(ref, node);
    }

    linear inout method InsertKeyValue(ref: BT.G.Reference, key: Key, msg: Message)
    requires old_self.Inv()
    requires old_self.ptr(ref).Some?
    requires |old_self.I()| <= 0x10000
    requires BT.WFNode(old_self.I()[ref])
    requires Pivots.BoundedKey(old_self.I()[ref].pivotTable, key)
    requires WeightBucketList(old_self.I()[ref].buckets) + WeightKey(key) 
      + WeightMessage(msg) < 0x1_0000_0000_0000_0000
    ensures self.Inv()
    ensures self.I() == old_self.I()
      [ref := BT.NodeInsertKeyValue(old_self.I()[ref], key, msg)]
    {
      linear var node := inout self.RemoveAndGet(ref);
      inout node.InsertKeyValue(key, msg);
      inout self.Insert(ref, node);
    }

    linear inout method SplitParent(ref: BT.G.Reference, slot: uint64, pivot: Key,
      left_childref: BT.G.Reference, right_childref: BT.G.Reference)
    requires old_self.Inv()
    requires old_self.ptr(ref).Some?
    requires BT.WFNode(old_self.I()[ref])
    requires old_self.I()[ref].children.Some?
    requires 0 <= slot as int < |old_self.I()[ref].children.value|
    requires 0 <= slot as int < |old_self.I()[ref].buckets|
    requires |old_self.I()| <= 0x10000
    ensures self.Inv()
    ensures self.I() == old_self.I()[ref := BT.SplitParent(old_self.I()[ref],
      pivot, slot as int, left_childref, right_childref)]
    {
      linear var node := inout self.RemoveAndGet(ref);
      inout node.SplitParent(slot, pivot, left_childref, right_childref);
      inout self.Insert(ref, node);
    }

    /// Temporary node borrow methods

    shared method GetNodeInfo(ref: BT.G.Reference)
    returns (pivots: Pivots.PivotTable, children: Option<seq<BT.G.Reference>>)
    requires Inv()
    requires ptr(ref).Some?
    ensures pivots == I()[ref].pivotTable
    ensures children == I()[ref].children
    {
      shared var node := Get(ref);
      children := node.children;
      pivots := node.pivotTable;
    }

    shared method GetNodeBucketsLen(ref: BT.G.Reference)
    returns (len: uint64)
    requires Inv()
    requires ptr(ref).Some?
    ensures len as nat == |I()[ref].buckets|
    {
      shared var node := Get(ref);
      len := lseq_length_as_uint64(node.buckets);
    }

    shared method GetMessage(ref: BT.G.Reference, i: uint64, key: KeyType.Key)
    returns (msg: Option<Message>)
    requires Inv()
    requires ptr(ref).Some?
    requires BT.WFNode(I()[ref])
    requires Pivots.BoundedKey(I()[ref].pivotTable, key)
    requires i as int == Pivots.Route(I()[ref].pivotTable, key)
    ensures 
      && var bucket := I()[ref].buckets[i];
      && msg == BucketsLib.bucketBinarySearchLookup(bucket, key)
    {
      shared var node := Get(ref);
      msg := lseq_peek(node.buckets, i).Query(key);
    }

    shared method NodeBucketsWeight(ref: BT.G.Reference)
    returns (weight: uint64)
    requires Inv()
    requires ptr(ref).Some?
    requires BT.WFNode(I()[ref])
    ensures weight as int == WeightBucketList(I()[ref].buckets)
    {
      shared var node := Get(ref);
      weight := MutBucket.computeWeightOfSeq(node.buckets);
    }

    shared method NodeBoundedBucket(ref: BT.G.Reference, 
      pivotsref: BT.G.Reference, slot: uint64)
    returns (b: bool)
    requires Inv()
    requires ref in I()
    requires pivotsref in I()
    requires BT.WFNode(I()[ref])
    requires BT.WFNode(I()[pivotsref])
    requires slot as nat < |I()[ref].buckets|
    ensures b == Pivots.BoundedKeySeq(I()[pivotsref].pivotTable,
        I()[ref].buckets[slot as nat].keys)
    {
      shared var node := Get(ref);
      if ref == pivotsref {
        b := node.BoundedBucket(node.pivotTable, slot);
      } else {
        shared var pivotsnode := Get(pivotsref);
        b := node.BoundedBucket(pivotsnode.pivotTable, slot);
      }
    }

    shared method NodePartialFlush(parentref: BT.G.Reference, 
      childref: BT.G.Reference, slot: uint64)
    returns (linear newparentBucket: MutBucket, linear newchild: Node)
    requires Inv()
    requires parentref in I()
    requires childref in I()
    requires BT.WFNode(I()[parentref])
    requires BT.WFNode(I()[childref])
    requires slot as nat < |I()[parentref].buckets|
    ensures newparentBucket.Inv()
    ensures newchild.Inv()
    ensures newchild.I().pivotTable == I()[childref].pivotTable
    ensures newchild.I().children == I()[childref].children
    ensures BucketFlushModel.partialFlushResult(newparentBucket.I(), newchild.I().buckets)
        == BucketFlushModel.partialFlush(I()[parentref].buckets[slot], 
          I()[childref].pivotTable, I()[childref].buckets)
    {
      shared var parent := Get(parentref);
      shared var child := Get(childref);

      WeightBucketLeBucketList(parent.I().buckets, slot as int);
      assert WeightBucketList(child.I().buckets) <= MaxTotalBucketWeight();

      linear var newpbucket, newbuckets := BucketImpl.PartialFlush(
        lseq_peek(parent.buckets, slot as uint64), child.buckets, child.pivotTable);

      newchild := Node(child.pivotTable, child.children, newbuckets);
      newparentBucket := newpbucket;
    }

    shared method NodeSplitMiddle(ref: BT.G.Reference)
    returns (linear left: MutBucket, linear right: MutBucket, pivot: Key)
    requires Inv()
    requires ref in I()
    requires BT.WFNode(I()[ref])
    requires |I()[ref].buckets| == 1
    ensures left.Inv()
    ensures right.Inv()
    ensures
      && var bucket := I()[ref].buckets[0];
      && pivot == BucketsLib.getMiddleKey(bucket)
      && left.I() == BucketsLib.SplitBucketLeft(bucket, pivot)
      && right.I() == BucketsLib.SplitBucketRight(bucket, pivot)
    {
      shared var node := Get(ref);
      shared var bucket := lseq_peek(node.buckets, 0);

      pivot := bucket.GetMiddleKey(); 
      left, right := MutBucket.SplitLeftRight(bucket, pivot);
    }

    shared method NodeCutOff(ref: BT.G.Reference, lbound: KeyType.Key, ubound: Option<KeyType.Key>)
    returns (linear node': Node)
    requires Inv()
    requires ptr(ref).Some?
    requires BT.WFNode(I()[ref])
    requires BT.ValidSplitKey(I()[ref], lbound, ubound)
    ensures node'.Inv()
    ensures node'.I() == BT.CutoffNode(I()[ref], lbound, ubound)
    {
      shared var node := Get(ref);
      node' := node.CutoffNode(lbound, ubound);
    }

    shared method NodeBucketGen(ref: BT.G.Reference, r: uint64, start: BT.UI.RangeStart)
    returns (linear g: BGI.Generator)
    requires Inv()
    requires ptr(ref).Some?
    requires BT.WFNode(I()[ref])
    requires r as nat < |I()[ref].buckets|
    ensures g.Basic?
    ensures g.biter.bucket == I()[ref].buckets[r as nat]
    ensures g.Inv()
    ensures g.I() == BGI.BucketGeneratorModel.GenFromBucketWithLowerBound(
        I()[ref].buckets[r as nat], start)
    {
      shared var node := Get(ref);
      g := BGI.Generator.GenFromBucketWithLowerBound(
          lseq_peek(node.buckets, r), start);
    }

    shared method NodeBiggestSlot(ref: BT.G.Reference)
    returns (res : (uint64, uint64))
    requires Inv()
    requires ptr(ref).Some?
    requires biggestSlot.requires(I()[ref].buckets)
    ensures res == biggestSlot(I()[ref].buckets)
    {
      shared var node := Get(ref);
      shared var buckets := node.buckets;

      WeightBucketLeBucketList(MutBucket.ILseq(buckets), 0);
      var j := 1;
      var bestIdx := 0;
      var bestWeight := lseq_peek(buckets, 0).weight;

      while j < lseq_length_as_uint64(buckets)
      invariant biggestSlotIterate.requires(MutBucket.ILseq(buckets), j, bestIdx, bestWeight)
      invariant biggestSlotIterate(MutBucket.ILseq(buckets), j, bestIdx, bestWeight) 
        == biggestSlot(MutBucket.ILseq(buckets))
      {
        WeightBucketLeBucketList(MutBucket.ILseq(buckets), j as int);
        var w := lseq_peek(buckets, j).weight;
        if w > bestWeight {
          bestIdx := j;
          bestWeight := w;
        }
        j := j + 1;
      }
      return (bestIdx, bestWeight);
    }
  }

  function method CacheCount(shared cache: LMutCache) : (c : uint64)
  requires cache.Inv()
  ensures c as int == |cache.I()|
  {
    cache.LemmaSizeEqCount();
    cache.cache.count
  }
}
