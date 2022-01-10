include "../DataStructures/KMBtree.i.dfy"
include "PackedKV.i.dfy"
include "../../PivotBetree/Bounds.i.dfy"
include "BucketIteratorModel.i.dfy"
include "BucketModel.i.dfy"
include "KMBPKVOps.i.dfy"

//
// Collects singleton message insertions efficiently, avoiding repeated
// replacement of the immutable root Node. Once this bucket is full,
// it is flushed into the root in a batch.
// This module implements PivotBetreeSpec.Bucket (the model for class
// MutBucket).
// The MutBucket class also supplies Iterators using the functional
// Iterator datatype from BucketIteratorModel, which is why there is no
// BucketIteratorImpl module/class.

module BucketImpl {
  import KMB = KMBtree`All
  import KMBBOps = KMBtreeBulkOperations
  import PackedKV
  import ValueType = ValueType`Internal
  import opened ValueMessage`Internal
  import opened Lexicographic_Byte_Order_Impl
  import opened Sequences
  import opened Options
  import opened Maps
  import opened BucketsLib
  import opened Bounds
  import opened BucketWeights
  import opened NativeTypes
  import opened KeyType
  import BucketIteratorModel
  import Pivots = PivotsLib
  import opened BucketModel
  import opened DPKV = DynamicPkv
  import KMBPKVOps
  
  type TreeMap = KMB.Node

  method pkv_to_tree(pkv: PackedKV.Pkv)
  returns (tree: TreeMap, weight: uint64)
  requires PackedKV.WF(pkv)
  ensures KMB.WF(tree)
  ensures KMBPKVOps.IsKeyMessageTree(tree)
  ensures PackedKV.I(pkv).b == B(KMB.Interpretation(tree)).b
  ensures weight as nat == BucketWeights.WeightBucket(BucketsLib.B(KMB.Interpretation(tree)))
  ensures fresh(tree.repr)
  {
    tree, weight := KMBPKVOps.FromPkv(pkv);
  }

  method tree_to_pkv(tree: TreeMap) returns (pkv : PackedKV.Pkv)
    requires KMB.WF(tree)
    requires KMBPKVOps.IsKeyMessageTree(tree)
    requires BucketWeights.WeightBucket(BucketsLib.B(KMB.Interpretation(tree))) < Uint32UpperBound()
    //requires PackedKV.BucketFitsInPkv(B(KMB.Interpretation(tree)))
    ensures PackedKV.WF(pkv)
    ensures PackedKV.I(pkv) == B(KMB.Interpretation(tree))
  {
    KMBPKVOps.WeightImpliesCanAppend(tree);
    // KMBPKVOps.ToSeqInterpretation(tree);
    // KMB.Model.ToSeqIsStrictlySorted(KMB.I(tree));
    // WellMarshalledBucketsEq(B(KMB.Interpretation(tree)),
    //     BucketMapWithSeq(KMB.Interpretation(tree), KMB.ToSeq(tree).0, KMB.ToSeq(tree).1));
    pkv := KMBPKVOps.ToPkv(tree);
  }

  datatype BucketFormat =
      | BFTree
      | BFPkv

  class MutBucket {
    var format: BucketFormat;

    var tree: KMB.Node?;
    var pkv: PackedKV.Pkv;

    var Weight: uint64;
    var sorted: bool

    ghost var Repr: set<object>;
    ghost var Bucket: Bucket;

    protected predicate Inv()
    reads this, Repr
    ensures Inv() ==> this in Repr
    ensures Inv() ==> Weight as int == WeightBucket(Bucket)
    ensures Inv() ==> WFBucket(Bucket)
    {
      && this in Repr
      && (format.BFTree? ==> (
        && tree != null
        && tree in Repr
        && tree.repr <= Repr
        && KMB.WF(tree)
        && KMBPKVOps.IsKeyMessageTree(tree)
        && Bucket == B(KMB.Interpretation(tree))
      ))
      && (format.BFPkv? ==> (
        && tree == null
        && PackedKV.WF(pkv)
        && Bucket == PackedKV.I(pkv)
      ))
      && WFBucket(Bucket)
      && (Weight as int == WeightBucket(Bucket))
      && Weight as int < Uint32UpperBound()
      && (sorted ==> BucketWellMarshalled(Bucket))
    }

    constructor()
    ensures Bucket == EmptyBucket()
    ensures Inv()
    ensures fresh(Repr)
    {
      this.format := BFTree;
      this.sorted := true;
      this.Weight := 0;
      var tmp := KMB.EmptyTree();
      this.tree := tmp;
      this.Repr := {this} + tmp.repr;
      this.Bucket := EmptyBucket();
    }

    function I() : Bucket
    reads this
    {
      this.Bucket
    }

    method Insert(key: Key, value: Message)
    requires Inv()
    requires Weight as int + WeightKey(key) + WeightMessage(value) < 0x1_0000_0000
    modifies Repr
    ensures Inv()
    ensures Bucket == BucketInsert(old(Bucket), key, value)
    ensures forall o | o in Repr :: o in old(Repr) || fresh(o)
    {
      if format.BFPkv? {
        format := BFTree;
        tree, Weight := pkv_to_tree(pkv);
        Bucket := B(Bucket.b);
        WeightWellMarshalledLe(old(Bucket), Bucket);
        var psa := PackedKV.PSA.Psa([], []);
        pkv := PackedKV.Pkv(psa, psa);
      }

      if value.Define? {
        var cur;
        tree, cur := KMB.Insert(tree, key, value);
        if (cur.Some?) {
          ghost var map0 := Maps.MapRemove1(Bucket.b, key);
          WeightBucketInduct(B(map0), key, cur.value);
          WeightBucketInduct(B(map0), key, value);
          assert Bucket.b[key := value] == map0[key := value];
          assert Bucket.b == map0[key := cur.value];
          Weight := Weight - WeightMessageUint64(cur.value) + WeightMessageUint64(value) as uint64;
        } else {
          WeightBucketInduct(Bucket, key, value);
          Weight := Weight + WeightKeyUint64(key) + WeightMessageUint64(value);
        }
      }

      ghost var mergedMsg := Merge(value, BucketGet(old(Bucket), key));
      assert mergedMsg == IdentityMessage() ==> KMB.Interpretation(tree) == MapRemove1(Bucket.b, key);
      assert mergedMsg != IdentityMessage() ==> KMB.Interpretation(tree) == Bucket.b[key := mergedMsg];

      Bucket := B(KMB.Interpretation(tree));
      Repr := {this} + tree.repr;
    }
  }
}

